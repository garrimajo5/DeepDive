extends SceneTree
func _initialize():
    var args = OS.get_cmdline_user_args()
    var doc = GLTFDocument.new()
    var state = GLTFState.new()
    var err = doc.append_from_file(args[0], state)
    if err != OK:
        push_error('GLB parse failed: %s' % err)
        quit(1)
        return
    var scene = doc.generate_scene(state)
    root.add_child(scene)
    var skels = scene.find_children('*', 'Skeleton3D', true, false)
    var players = scene.find_children('*', 'AnimationPlayer', true, false)
    var meshes = scene.find_children('*', 'MeshInstance3D', true, false)
    var report = {'skeletons': skels.size(), 'meshes': meshes.size(), 'clips': {}}
    assert(skels.size() == 1 and skels[0].get_bone_count() == 10)
    assert(meshes.size() == 3 and players.size() == 1)
    for m in meshes:
        assert(m.skin != null)
    var player = players[0]
    for name in ['Swim', 'SwimFast', 'Bite', 'TailStrike']:
        assert(player.has_animation(name))
        var anim = player.get_animation(name)
        var max_edge = 0.0
        for i in anim.get_track_count():
            if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
                var first = anim.track_get_key_value(i, 0)
                var last = anim.track_get_key_value(i, anim.track_get_key_count(i)-1)
                max_edge = max(max_edge, first.angle_to(last))
        assert(max_edge < 0.001)
        player.play(name)
        for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
            player.seek(anim.length*t, true)
            for b in skels[0].get_bone_count():
                assert(skels[0].get_bone_global_pose(b).is_finite())
        report.clips[name] = {'seconds': anim.length, 'tracks': anim.get_track_count(), 'endpoint_angle_error': max_edge}
    player.play('Bite')
    player.seek(0.4, true)
    await process_frame
    skels[0].force_update_all_bone_transforms()
    var jaw = skels[0].find_bone('Jaw')
    var tip = Vector3(0, 0.55, 0)
    var closed = skels[0].get_bone_global_rest(jaw) * tip
    var transform = skels[0].get_bone_pose(jaw)
    var parent_bone = skels[0].get_bone_parent(jaw)
    while parent_bone >= 0:
        transform = skels[0].get_bone_pose(parent_bone) * transform
        parent_bone = skels[0].get_bone_parent(parent_bone)
    var opened = transform * tip
    print('JAW CHECK ', closed, ' / ', opened, ' pose ', skels[0].get_bone_pose_rotation(jaw))
    if not opened.y < closed.y - 0.2:
        quit(1)
        return
    report.jaw_tip_drop_m = closed.y - opened.y
    report.bones = skels[0].get_bone_count()
    print('VERIFIED ', JSON.stringify(report))
    FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, '  '))
    quit(0)
