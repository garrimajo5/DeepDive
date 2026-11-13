"""Necessary continuous-time bound, assuming wind-up peak at t=0.35 (v_y=0).
This is not a GLB/Godot acceptance measurement; discrete acceleration alone
cannot establish a continuous acceleration bound.
"""
import math,json
from pathlib import Path
A=60.;down_time=.20;distance=1.1;return_time=.35
# To travel D from rest in T, smallest possible terminal speed is obtained
# with +A then -A, using the largest permissible early displacement.
v=A*down_time-2*math.sqrt(A*(A*down_time**2/2-distance))
# Maximum return displacement with starting velocity -v and ending velocity 0:
# accelerate +A, then -A, switching to finish at rest.
max_return=A*return_time**2/4-v*return_time/2-v*v/(4*A)
min_return_time=(v+math.sqrt(2*v*v+4*A*.8))/A
r={'assumption':'vertical wind-up maximum at .35s; y=.3m; vy=0; y(.55)<=-.8; y(.9)=0; vy(.9)=0; continuous |ay|<=60',
'min_downward_speed_at_055':v,'max_return_displacement_by_09':max_return,'required_return_displacement':.8,'earliest_possible_rest_return':.55+min_return_time,
'limitation':'Necessary bound only; assumes peak at .35. Does not rule out earlier peak or claim a sampled Godot measurement.'}
p=Path(__file__).resolve().parents[1]/'timing-bound.json';p.write_text(json.dumps(r,indent=2),encoding='utf-8');print(json.dumps(r,indent=2))
