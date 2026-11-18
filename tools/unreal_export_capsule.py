"""Exporta a cena da cabine (/Game/ProfundidadeZero/Capsule) como peças separadas para a Godot.

Para cada malha única: FBX com a malha de origem (Nanite incluído), sem LODs/colisão.
Para cada material usado: texturas relevantes (cor, ORM, normal, emissiva) em PNG na resolução
original (UDIM sai como NOME.1001.png ...). Gera manifest.json com atores, transforms e materiais.

Uso (sem abrir o editor):
  UnrealEditor-Cmd.exe "<Projeto>.uproject" -run=pythonscript -script="<este arquivo>"
      -EnablePlugins=PythonScriptPlugin -unattended -nopause -nosplash -stdout
Pasta de saída: variável de ambiente EXPORT_OUT (padrão: export_capsule/ ao lado do script).
Depois: tools/prepare_capsule_textures.gd reduz as texturas e tools/build_capsule_scene.gd monta a cena.
"""
import json
import os

import unreal

MAP = "/Game/ProfundidadeZero/Capsule"
OUT = os.environ.get("EXPORT_OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "export_capsule"))
# Parâmetros de textura que a Godot aproveita (os demais são máscaras/detalhes dos materiais mestres).
TEXTURE_PARAMS = {"BC", "BaseColor", "Albedo", "Diffuse", "ORM", "AORM", "RMA", "SRMH",
                  "N", "Normal", "Normals", "Emissive", "EmColor", "emmisive"}

os.makedirs(os.path.join(OUT, "meshes"), exist_ok=True)
os.makedirs(os.path.join(OUT, "textures"), exist_ok=True)
log_lines = []


def log(msg):
    log_lines.append(str(msg))
    unreal.log("[export_capsule] " + str(msg))


def run_export(obj, filename, options=None):
    task = unreal.AssetExportTask()
    task.object = obj
    task.filename = filename
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    if options is not None:
        task.options = options
    ok = unreal.Exporter.run_asset_export_task(task)
    if not ok:
        log(f"FALHOU: {obj.get_name()} -> {filename} {list(task.errors or [])}")
    return ok


def fbx_options():
    opts = unreal.FbxExportOption()
    for prop, value in (
        ("fbx_export_compatibility", unreal.FbxExportCompatibility.FBX_2020),
        ("ascii", False),
        ("level_of_detail", False),
        ("collision", False),
        ("vertex_color", True),
        ("export_source_mesh", True),
    ):
        try:
            opts.set_editor_property(prop, value)
        except Exception as e:
            log(f"opção {prop} indisponível: {e}")
    return opts


def color(c):
    return [c.r, c.g, c.b, c.a]


unreal.EditorLoadingAndSavingUtils.load_map(MAP)
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
mel = unreal.MaterialEditingLibrary

placements, meshes, materials, textures = [], {}, {}, {}


def describe_material(m):
    path = m.get_path_name()
    if path in materials:
        return
    base = m.get_base_material()
    d = {
        "name": m.get_name(),
        "base": base.get_name(),
        "blend": str(base.get_editor_property("blend_mode")).split(".")[-1].split(":")[0],
        "two_sided": bool(base.get_editor_property("two_sided")),
        "scalars": {}, "vectors": {}, "textures": {},
    }
    if isinstance(m, unreal.MaterialInstance):
        d["scalars"] = {str(n): mel.get_material_instance_scalar_parameter_value(m, n) for n in mel.get_scalar_parameter_names(m)}
        d["vectors"] = {str(n): color(mel.get_material_instance_vector_parameter_value(m, n)) for n in mel.get_vector_parameter_names(m)}
        for n in mel.get_texture_parameter_names(m):
            key = str(n).strip()
            t = mel.get_material_instance_texture_parameter_value(m, n)
            if t and key in TEXTURE_PARAMS and isinstance(t, unreal.Texture2D):
                d["textures"][key] = t.get_name()
                textures[t.get_path_name()] = t
    materials[path] = d


for a in actors:
    for c in a.get_components_by_class(unreal.StaticMeshComponent):
        sm = c.get_editor_property("static_mesh")
        if not sm or not c.is_visible() or a.is_hidden_ed():
            continue
        mpath = sm.get_path_name()
        if mpath not in meshes:
            slots = []
            for s in sm.get_editor_property("static_materials"):
                mi = s.get_editor_property("material_interface")
                slots.append(mi.get_name() if mi else None)
            meshes[mpath] = {"name": sm.get_name(), "slots": slots}
        mats = []
        for i in range(c.get_num_materials()):
            m = c.get_material(i)
            mats.append(m.get_path_name() if m else None)
            if m:
                describe_material(m)
        t = c.get_world_transform()
        placements.append({
            "actor": a.get_actor_label(),
            "mesh": sm.get_name(),
            "loc": [t.translation.x, t.translation.y, t.translation.z],
            "quat": [t.rotation.x, t.rotation.y, t.rotation.z, t.rotation.w],
            "scale": [t.scale3d.x, t.scale3d.y, t.scale3d.z],
            "materials": [materials[p]["name"] if p else None for p in mats],
        })

log(f"{len(placements)} atores, {len(meshes)} malhas, {len(materials)} materiais, {len(textures)} texturas")

opts = fbx_options()
for mpath, info in meshes.items():
    sm = unreal.load_asset(mpath)
    run_export(sm, os.path.join(OUT, "meshes", info["name"] + ".fbx"), opts)

tex_info = {}
for tpath, t in textures.items():
    info = {"srgb": bool(t.get_editor_property("srgb")),
            "compression": str(t.get_editor_property("compression_settings")).split(".")[-1].split(":")[0]}
    try:
        info["size"] = [t.blueprint_get_size_x(), t.blueprint_get_size_y()]
    except Exception:
        pass
    info["exported"] = run_export(t, os.path.join(OUT, "textures", t.get_name() + ".png"))
    tex_info[t.get_name()] = info

manifest = {
    "map": MAP,
    "placements": placements,
    "meshes": {v["name"]: v for v in meshes.values()},
    "materials": {v["name"]: v for v in materials.values()},
    "textures": tex_info,
}
with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=1, ensure_ascii=False)
with open(os.path.join(OUT, "export_log.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(log_lines))
log("FIM")
