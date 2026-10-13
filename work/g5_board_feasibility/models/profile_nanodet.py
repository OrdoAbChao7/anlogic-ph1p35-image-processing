import sys,json,math,hashlib,collections
from pathlib import Path
OUT=Path(__file__).resolve().parent;sys.path.insert(0,str(OUT/'deps'))
import onnx
from onnx import shape_inference,numpy_helper
p=OUT/'nanodet-plus-m_320.onnx';m=onnx.load(p);onnx.checker.check_model(m)
m=shape_inference.infer_shapes(m);g=m.graph
shapes={x.name:[d.dim_value for d in x.type.tensor_type.shape.dim] for x in list(g.input)+list(g.value_info)+list(g.output)}
init={x.name:x for x in g.initializer};layers=[]
for node in g.node:
 r={'name':node.name,'op':node.op_type,'inputs':list(node.input),'outputs':list(node.output),'output_shapes':[shapes.get(x) for x in node.output]}
 if node.op_type=='Conv':
  w=init[node.input[1]];shape=list(w.dims);output=shapes[node.output[0]]
  r.update(weight_shape=shape,parameters=math.prod(shape),mac=math.prod(output)*math.prod(shape[1:]),groups=next((a.i for a in node.attribute if a.name=='group'),1))
 layers.append(r)
unknown=[r['name'] for r in layers if any(not s or any(d<=0 for d in s) for s in r['output_shapes'])]
result={'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'graph_check':'PASS','initializer_elements':sum(math.prod(x.dims) for x in g.initializer),'conv_weight_elements':sum(x.get('parameters',0) for x in layers),'conv_mac':sum(x.get('mac',0) for x in layers),'largest_single_int8_feature_bytes':max(math.prod(s) for r in layers for s in r['output_shapes'] if s),'unknown_shapes':unknown,'operators':dict(collections.Counter(n.op_type for n in g.node)),'layers':layers}
last={}
for i,n in enumerate(g.node):
 for x in n.input:last[x]=i
live={};peak=0;peak_at=None
for i,n in enumerate(g.node):
 for x in n.output:
  s=shapes.get(x)
  if s and all(d>0 for d in s):live[x]=math.prod(s)
 if sum(live.values())>peak:peak=sum(live.values());peak_at=n.name
 for x in list(live):
  if last.get(x,i)<=i:del live[x]
result.update(conservative_int8_graph_live_bytes=peak,peak_node=peak_at,note='FP32 original graph. INT8 sizes are hypothetical, count alias outputs separately; shape tensors counted as one byte/element. Not optimized FPGA BRAM, quantization or schedule.')
(OUT/'nanodet_profile.json').write_text(json.dumps(result,indent=2));print({k:v for k,v in result.items() if k!='layers'})
