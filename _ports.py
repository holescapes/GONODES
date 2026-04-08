import json
with open('scripts/port_registry.json', 'r', encoding='utf-8') as f:
    preg = json.load(f)

targets = [
    'CurlNoiseTOP','FlowVisTOP','TestCardTOP','CacheTOP','CrossTOP',
    'FeedbackTOP','Fluid2DTOP','GeometryBufferTOP','GlueTOP',
    'HostInTOP','LayoutTOP','LimitTOP','LookupTOP','MatteTOP',
    'MovieFileInTOP','MultiBufferRenderTOP','OpticalFlowTOP',
    'PanelTOP','ParticleStateTOP','PointCloudRenderTOP',
    'PremultiplyTOP','RenderTOP','SelectTOP','SnapshotTOP',
    'TimeMachineTOP','VectorPathTOP','CHOPtoTOP',
    'ConstantTOP','CompositorEffectTOP','ComputeShaderTOP','GLSLMultiTOP'
]
for op_name in sorted(targets):
    entry = preg.get(op_name, {})
    ins = entry.get('inputs', [])
    outs = entry.get('outputs', [])
    in_str = ', '.join(p['name'] + '(' + p['type'] + ')' for p in ins) if ins else 'none'
    out_str = ', '.join(p['name'] + '(' + p['type'] + ')' for p in outs) if outs else 'none'
    dyn = entry.get('dynamic_inputs')
    dyn_str = f" DYN={dyn}" if dyn else ""
    print(f"{op_name}: IN=[{in_str}] OUT=[{out_str}]{dyn_str}")
