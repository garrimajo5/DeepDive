extends SceneTree
func _initialize():
    var args = OS.get_cmdline_user_args()
    var report = []
    for sex in ["m", "zh"]:
        var body = load_glb(args[1] + "/ekipazh-" + ("muzhchina" if sex == "m" else "zhenshchina") + ".glb")
        root.add_child(body)
        var sk = body.find_children("*", "Skeleton3D", true, false)[0]
        for kind in ["fartuk", "tunika"]:
            var name = "gear-" + kind + "-" + sex
            var scene = load_glb(args[0] + "/" + name + ".glb")
            root.add_child(scene)
            var own = scene.find_children("*", "Skeleton3D", true, false)[0]
            var meshes = scene.find_children("*", "MeshInstance3D", true, false)
            assert(meshes.size() == 1)
            var mi = meshes[0]
            assert(mi.mesh.get_surface_count() == 1)
            assert(mi.scale.is_equal_approx(Vector3.ONE))
            assert(mi.skin != null)
            var max_rest_error = 0.0
            for i in own.get_bone_count():
                var target = sk.find_bone(own.get_bone_name(i))
                assert(target >= 0)
                var a = own.get_bone_global_rest(i)
                var b = sk.get_bone_global_rest(target)
                max_rest_error = max(max_rest_error, a.origin.distance_to(b.origin))
                assert(a.is_equal_approx(b))
            # Resolve bind names explicitly before reusing the body's Skeleton3D.
            var skin = mi.skin.duplicate()
            for b in skin.get_bind_count():
                var old_index = skin.get_bind_bone(b)
                var bone_name = skin.get_bind_name(b)
                if bone_name == "":
                    bone_name = own.get_bone_name(old_index)
                assert(sk.find_bone(bone_name) >= 0)
                skin.set_bind_bone(b, sk.find_bone(bone_name))
                skin.set_bind_name(b, bone_name)
            mi.owner = null
            mi.reparent(sk, false)
            mi.skeleton = NodePath("..")
            mi.skin = skin
            var mat = mi.mesh.surface_get_material(0)
            assert(mat.albedo_texture != null)
            assert(mat.albedo_texture.get_width() == 1024 and mat.albedo_texture.get_height() == 1024)
            var arrays = mi.mesh.surface_get_arrays(0)
            var verts = arrays[Mesh.ARRAY_VERTEX]
            var joints = arrays[Mesh.ARRAY_BONES]
            var weights = arrays[Mesh.ARRAY_WEIGHTS]
            var stride = joints.size() / verts.size()
            var moved = 0
            var max_error = 0.0
            for v in verts.size():
                var p = Vector3.ZERO
                var total = 0.0
                for j in stride:
                    var w = weights[v * stride + j]
                    var bi = joints[v * stride + j]
                    if w > 0:
                        p += w * (sk.get_bone_global_rest(skin.get_bind_bone(bi)) * skin.get_bind_pose(bi) * verts[v])
                        total += w
                assert(abs(total - 1.0) < 0.001)
                max_error = max(max_error, p.distance_to(verts[v]))
            assert(max_error < 0.0001)
            report.append({"name":name,"bone_count":own.get_bone_count(),"skin_binds":skin.get_bind_count(),"surfaces":mi.mesh.get_surface_count(),"vertices":verts.size(),"triangles":arrays[Mesh.ARRAY_INDEX].size()/3,"rest_error_m":max_rest_error,"skin_rest_error_m":max_error,"shared_body_skeleton":mi.get_node(mi.skeleton)==sk,"texture":"1024x1024","bone_attachment_count":scene.find_children("*","BoneAttachment3D",true,false).size()})
            mi.free()
            scene.free()
        body.free()
    FileAccess.open(args[2],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PASS: four GLBs, same body rests, shared Skeleton3D, valid skins, one surface and embedded 1024 texture")
    quit(0)
func load_glb(path):
    var doc = GLTFDocument.new()
    var state = GLTFState.new()
    assert(doc.append_from_file(path,state) == OK)
    return doc.generate_scene(state)
