"""Exporta SM_Devices01 (malha de origem, sem LODs/colisao), texturas originais e parametros do material.

Uso (sem abrir o editor):
  UnrealEditor-Cmd.exe "<Projeto>.uproject" -run=pythonscript -script="<este arquivo>"
      -EnablePlugins=PythonScriptPlugin -unattended -nopause -nosplash -stdout
Pasta de saida: variavel de ambiente EXPORT_OUT (padrao: export_sm_devices01/ ao lado do script).
As texturas sao UDIM: saem como T_*.1001.png ... T_*.1006.png. Ao copiar para a Godot,
renomear para T_*_1001.png (ver assets/imports/sm_devices01/sm_devices01_import.gd).
"""
import json
import os

import unreal

OUT = os.environ.get(
    "EXPORT_OUT",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "export_sm_devices01"),
)
MESH_PATH = "/Game/DeepWaterStation/Meshes/SM_Devices01"

os.makedirs(OUT, exist_ok=True)
log_lines = []


def log(msg):
    log_lines.append(str(msg))
    unreal.log("[export_devices01] " + str(msg))


def try_set(obj, prop, value):
    try:
        obj.set_editor_property(prop, value)
        log(f"  opt {prop} = {value}")
    except Exception as e:  # propriedade pode nao existir nesta versao
        log(f"  opt {prop} indisponivel: {e}")


def export(obj, filename, options=None):
    task = unreal.AssetExportTask()
    task.object = obj
    task.filename = filename
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    if options is not None:
        task.options = options
    ok = unreal.Exporter.run_asset_export_task(task)
    log(f"export {obj.get_name()} -> {filename}: {'OK' if ok else 'FALHOU'}")
    for err in task.errors or []:
        log(f"  erro: {err}")
    return ok


def color_to_list(c):
    return [round(c.r, 5), round(c.g, 5), round(c.b, 5), round(c.a, 5)]


mesh = unreal.load_asset(MESH_PATH)
if mesh is None:
    raise RuntimeError("Malha nao encontrada: " + MESH_PATH)

info = {"mesh": MESH_PATH}

# --- Informacoes da malha ---
try:
    nanite = mesh.get_editor_property("nanite_settings")
    info["nanite_enabled"] = bool(nanite.enabled)
except Exception as e:
    info["nanite_enabled"] = f"? ({e})"
try:
    info["lod0_vertices"] = mesh.get_num_vertices(0)
    info["lod0_triangles"] = mesh.get_num_triangles(0)
    info["num_lods"] = mesh.get_num_lods()
except Exception as e:
    log(f"stats indisponiveis: {e}")
try:
    b = mesh.get_bounds()
    info["bounds_extent_cm"] = [b.box_extent.x, b.box_extent.y, b.box_extent.z]
except Exception as e:
    log(f"bounds indisponiveis: {e}")
log(f"malha: {info}")

# --- FBX ---
opts = unreal.FbxExportOption()
try_set(opts, "fbx_export_compatibility", unreal.FbxExportCompatibility.FBX_2020)
try_set(opts, "ascii", False)
try_set(opts, "level_of_detail", False)
try_set(opts, "collision", False)
try_set(opts, "vertex_color", True)
try_set(opts, "bake_material_inputs", unreal.FbxMaterialBakeMode.DISABLED if hasattr(unreal, "FbxMaterialBakeMode") else False)
try_set(opts, "export_source_mesh", True)  # Nanite: exporta a malha de alta resolucao, nao o fallback
export(mesh, os.path.join(OUT, "SM_Devices01.fbx"), opts)

# --- Materiais e texturas ---
materials = []
textures = {}
for slot in mesh.get_editor_property("static_materials"):
    mi = slot.get_editor_property("material_interface")
    entry = {
        "slot": str(slot.get_editor_property("material_slot_name")),
        "material": mi.get_path_name() if mi else None,
    }
    if isinstance(mi, unreal.MaterialInstance):
        parent = mi.get_editor_property("parent")
        entry["parent"] = parent.get_path_name() if parent else None
        entry["scalars"] = {
            str(p.parameter_info.name): p.parameter_value
            for p in mi.get_editor_property("scalar_parameter_values")
        }
        entry["vectors"] = {
            str(p.parameter_info.name): color_to_list(p.parameter_value)
            for p in mi.get_editor_property("vector_parameter_values")
        }
        entry["textures"] = {}
        for p in mi.get_editor_property("texture_parameter_values"):
            tex = p.parameter_value
            if tex:
                entry["textures"][str(p.parameter_info.name)] = tex.get_name()
                textures[tex.get_path_name()] = tex
        # Parametros herdados do material pai (valores padrao) - ajuda a recriar na Godot
        try:
            mel = unreal.MaterialEditingLibrary
            entry["all_scalar_params"] = {
                str(n): mel.get_material_instance_scalar_parameter_value(mi, n)
                for n in mel.get_scalar_parameter_names(mi)
            }
            entry["all_vector_params"] = {
                str(n): color_to_list(mel.get_material_instance_vector_parameter_value(mi, n))
                for n in mel.get_vector_parameter_names(mi)
            }
            entry["all_texture_params"] = {}
            for n in mel.get_texture_parameter_names(mi):
                t = mel.get_material_instance_texture_parameter_value(mi, n)
                entry["all_texture_params"][str(n)] = t.get_name() if t else None
                if t:
                    textures[t.get_path_name()] = t
        except Exception as e:
            log(f"parametros herdados indisponiveis: {e}")
    materials.append(entry)
info["materials"] = materials

tex_info = []
for path, tex in textures.items():
    name = tex.get_name()
    t = {"name": name, "path": path}
    try:
        t["size"] = [tex.blueprint_get_size_x(), tex.blueprint_get_size_y()]
        t["srgb"] = bool(tex.get_editor_property("srgb"))
        t["compression"] = str(tex.get_editor_property("compression_settings"))
    except Exception as e:
        log(f"info textura {name}: {e}")
    # Exporta os dados de origem (resolucao original importada)
    ok = export(tex, os.path.join(OUT, name + ".png"))
    if not ok:
        ok = export(tex, os.path.join(OUT, name + ".tga"))
    t["exported"] = ok
    tex_info.append(t)
info["textures"] = tex_info

with open(os.path.join(OUT, "SM_Devices01_material.json"), "w", encoding="utf-8") as f:
    json.dump(info, f, indent=2, ensure_ascii=False)
with open(os.path.join(OUT, "export_log.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(log_lines))
log("FIM")
