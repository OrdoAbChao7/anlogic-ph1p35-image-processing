"""Simulate untouched reference RTL against independent integer arithmetic."""
import json
import random
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "upstream/fpga_accelerator_yolov3tiny/vivado_prj/source"
SIM = Path("E:/Projects/FPGA/.tools/iverilog/bin")
OUT = ROOT / "results/rtl"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(20261012)


def signed(n, bits):
    n &= (1 << bits) - 1
    return n - (1 << bits) if n & (1 << (bits - 1)) else n


def vectors():
    boundary = [-128, -127, -1, 0, 1, 127]
    cases = []
    for a in boundary:
        for b in boundary:
            cases.append((a, b, -128))
            cases.append((a, b, 127))
    cases += [(random.randint(-128,127),random.randint(-128,127),random.randint(-128,127)) for _ in range(300)]
    return cases


def run(name, tb, sources):
    path = OUT / f"{name}.v"
    path.write_text(tb, encoding="ascii")
    exe = OUT / f"{name}.vvp"
    build = subprocess.run([str(SIM/"iverilog.exe"),"-g2012","-o",str(exe),str(path),
                            *[str(SOURCE/s if not str(s).startswith("rtl_candidate/") else ROOT/s) for s in sources]],capture_output=True,text=True)
    (OUT/f"{name}.build.log").write_text(build.stdout+build.stderr,encoding="utf-8")
    if build.returncode:
        raise RuntimeError(f"{name} build: {build.stderr}")
    proc = subprocess.run([str(SIM/"vvp.exe"),str(exe)],capture_output=True,text=True)
    (OUT/f"{name}.simulation.log").write_text(proc.stdout+proc.stderr,encoding="utf-8")
    if proc.returncode:
        raise RuntimeError(f"{name} sim: {proc.stderr}")
    return proc.stdout.splitlines()


def check_multiplier():
    cases = vectors()
    body = []
    for i,(a,b,c) in enumerate(cases):
        body.append(f"a={a}; b={b}; c={c}; repeat (6) @(negedge clk); $display(\"V {i} %0d %0d\",ac,bc);")
    tb = """module tb;
reg clk=0; always #5 clk=~clk;
reg signed [7:0] a,b,c; wire signed [15:0] ac,bc;
cal_mult_int8_x2 dut(clk,a,b,c,ac,bc);
initial begin a=0;b=0;c=0;
"""+"\n".join(body)+"\n$finish; end endmodule\n"
    lines = run("multiplier_original",tb,["cal_mul_int8_x2.v","cal_mul_int8_x2_dsp.v"])
    mismatches=[]
    for line in lines:
        if not line.startswith("V "): continue
        _,i,ac,bc=line.split(); i=int(i);a,b,c=cases[i]
        expect=(a*c,b*c)
        actual=(int(ac),int(bc))
        if actual!=expect: mismatches.append({"index":i,"inputs":[a,b,c],"expected":expect,"actual":actual})
    return {"vectors":len(cases),"observed":len([x for x in lines if x.startswith('V ')]),"mismatches":mismatches}


def check_adder(candidate=False):
    cases=[[16384]*9,[-16384]*9,[127*127]*9,[-128*-128]*9,[0]*9]
    cases += [[random.randint(-16384,16384) for _ in range(9)] for _ in range(300)]
    port=",".join(f"a{i}" for i in range(1,10))
    decl="\n".join(f"reg signed [15:0] a{i};" for i in range(1,10))
    body=[]
    for i,v in enumerate(cases):
        ass=" ".join(f"a{k+1}={x};" for k,x in enumerate(v))
        body.append(f"{ass} repeat (3) @(negedge clk); $display(\"V {i} %0d\",dout);")
    mod = "cal_addtree_int16_x9_wide" if candidate else "cal_addtree_int16_x9"
    width = 18 if candidate else 17
    tb=f"module tb; reg clk=0; always #5 clk=~clk; {decl} wire signed [{width}:0] dout; {mod} dut(clk,{port},dout); initial begin\n"+"\n".join(body)+"\n$finish; end endmodule\n"
    lines=run("adder_candidate" if candidate else "adder_original",tb,["rtl_candidate/cal_addtree_int16_x9_wide.v"] if candidate else ["cal_addtree_int16_x9.v"])
    mismatches=[]
    for line in lines:
        if not line.startswith("V "):continue
        _,i,value=line.split();i=int(i)
        exact=sum(cases[i]); actual=int(value)
        if exact!=actual:mismatches.append({"index":i,"inputs":cases[i],"exact":exact,"actual":actual,"wrapped_18bit":signed(exact,18)})
    return {"vectors":len(cases),"observed":len([x for x in lines if x.startswith('V ')]),"mismatches":mismatches}


def check_scale_sat():
    cases=[(x,s) for x in [-2147483648,-1073741824,-32769,-32768,-32767,-1,0,1,16383,16384,32767,32768,2147483647] for s in [0,1,7,15]]
    cases += [(random.randint(-2**31,2**31-1),random.randint(0,15)) for _ in range(300)]
    body=[]
    for i,(value,shift) in enumerate(cases):
        body.append(f"din=32'sh{value & 0xffffffff:08x}; sh={shift}; repeat (3) @(negedge clk); $display(\"V {i} %0d %0d\",scaled,sat);")
    tb="""module tb; reg clk=0; always #5 clk=~clk;
reg signed [31:0] din; reg [3:0] sh; wire signed [15:0] scaled; wire [7:0] sat;
cal_scale_shift u1(clk,din,sh,scaled); cal_sat_int16_int8 u2(clk,scaled,sat);
initial begin din=0;sh=0;
"""+"\n".join(body)+"\n$finish; end endmodule\n"
    lines=run("scale_sat_original",tb,["cal_scale_shift.v","cal_sat_int16_int8.v"])
    mismatches=[]
    for line in lines:
        if not line.startswith("V "):continue
        _,i,sc,st=line.split();i=int(i);value,shift=cases[i]
        # Independent definition of original bit-slice rounding, not a claim it is the desired quantizer.
        rounded=signed((value >> (15+shift))+((value >> (14+shift))&1),16)
        saturated=max(-128,min(127,rounded))&255
        actual=(int(sc),int(st))
        if actual!=(rounded,saturated): mismatches.append({"index":i,"input":cases[i],"expected":[rounded,saturated],"actual":actual})
    return {"vectors":len(cases),"observed":len([x for x in lines if x.startswith('V ')]),"mismatches":mismatches}


def check_chain():
    cases=[]
    edges=[-128,-127,-1,0,1,127]
    for a in edges:
        for w in edges:
            cases.append(([a]*9,[w]*9,0,15))
    cases += [([random.randint(-128,127) for _ in range(9)],
               [random.randint(-128,127) for _ in range(9)],
               random.randint(-10000,10000),random.randint(0,15)) for _ in range(150)]
    decl="\n".join(f"reg signed [7:0] a{i},w{i}; wire signed [15:0] prod{i},unused{i};\ncal_mult_int8_x2 m{i}(clk,a{i},w{i},w{i},prod{i},unused{i});" for i in range(9))
    prod=",".join(f"prod{i}" for i in range(9))
    body=[]
    for idx,(pixels,weights,bias,shift) in enumerate(cases):
        assign=" ".join(f"a{i}={pixels[i]};w{i}={weights[i]};" for i in range(9))
        body.append(f"{assign} bias=32'sh{bias & 0xffffffff:08x}; sh={shift}; repeat(12) @(negedge clk); $display(\"V {idx} %0d %0d %0d\",sum19,scaled,sat);")
    tb="""module tb;reg clk=0;always #5 clk=~clk;
reg signed [31:0] bias;reg [3:0] sh;
"""+decl+f"\nwire signed [18:0] sum19; cal_addtree_int16_x9_wide add(clk,{prod},sum19);\n"+"""wire signed [31:0] biased={{13{sum19[18]}},sum19}+bias;
wire signed [15:0] scaled;wire [7:0] sat;
cal_scale_shift scale(clk,biased,sh,scaled);
cal_sat_int16_int8 saturate(clk,scaled,sat);
initial begin bias=0;sh=0;
"""+"\n".join(body)+"\n$finish;end endmodule\n"
    lines=run("chain_candidate",tb,["cal_mul_int8_x2.v","cal_mul_int8_x2_dsp.v", "rtl_candidate/cal_addtree_int16_x9_wide.v","cal_scale_shift.v","cal_sat_int16_int8.v"])
    mismatches=[]
    expectations=[]
    for idx,(pixels,weights,bias,shift) in enumerate(cases):
        total=sum(x*y for x,y in zip(pixels,weights))
        biased=signed(total+bias,32)
        scaled=signed((biased>>(15+shift))+((biased>>(14+shift))&1),16)
        sat=max(-128,min(127,scaled))&255
        expectations.append({"index":idx,"pixels":pixels,"weights":weights,"bias":bias,"shift":shift,"expected":[total,scaled,sat]})
    for line in lines:
        if not line.startswith("V "):continue
        _,idx,ad,sc,st=line.split();idx=int(idx)
        actual=[int(ad),int(sc),int(st)]
        if actual!=expectations[idx]["expected"]:mismatches.append({"index":idx,"expected":expectations[idx],"actual":actual})
    (OUT/"chain_vectors_expected.json").write_text(json.dumps(expectations,indent=2),encoding="utf-8")
    return {"vectors":len(cases),"observed":len([x for x in lines if x.startswith('V ')]),"mismatches":mismatches}


def check_continuous_latency():
    seq=[(random.randint(-128,127),random.randint(-128,127),random.randint(-128,127),
          random.randint(-16000,16000),random.randint(-2**30,2**30-1),random.randint(0,15)) for _ in range(120)]
    body=[]
    for i,(a,b,c,add,din,sh) in enumerate(seq):
        body.append(f"@(negedge clk);a={a};b={b};c={c};av={add};din=32'sh{din & 0xffffffff:08x};sh={sh};@(posedge clk);#1;$display(\"V {i} %0d %0d %0d %0d\",ac,bc,sum19,sat);")
    for i in range(5):
        body.append(f"@(negedge clk);a=0;b=0;c=0;av=0;din=0;sh=0;@(posedge clk);#1;$display(\"V {len(seq)+i} %0d %0d %0d %0d\",ac,bc,sum19,sat);")
    tb="""module tb;reg clk=0;always #5 clk=~clk;
reg signed [7:0] a,b,c; wire signed [15:0] ac,bc;
reg signed [15:0] av;wire signed [18:0] sum19;
reg signed [31:0] din;reg [3:0] sh;wire signed [15:0] scaled;wire [7:0] sat;
cal_mult_int8_x2 mult(clk,a,b,c,ac,bc);
cal_addtree_int16_x9_wide add(clk,av,av,av,av,av,av,av,av,av,sum19);
cal_scale_shift scale(clk,din,sh,scaled);cal_sat_int16_int8 clamp(clk,scaled,sat);
initial begin a=0;b=0;c=0;av=0;din=0;sh=0;
"""+"\n".join(body)+"\n$finish;end endmodule\n"
    lines=run("continuous_latency",tb,["cal_mul_int8_x2.v","cal_mul_int8_x2_dsp.v","rtl_candidate/cal_addtree_int16_x9_wide.v","cal_scale_shift.v","cal_sat_int16_int8.v"])
    mismatches=[];checked=0
    for line in lines:
        if not line.startswith("V "):continue
        _,i,ac,bc,ad,st=line.split();i=int(i)
        if i>=3 and i-3<len(seq):
            a,b,c,*_=seq[i-3];checked+=2
            if (int(ac),int(bc))!=(a*c,b*c):mismatches.append({"cycle":i,"module":"multiplier","expected":[a*c,b*c],"actual":[int(ac),int(bc)]})
        if i>=1 and i-1<len(seq):
            a,b,c,av,din,sh=seq[i-1];checked+=2
            expected_sum=9*av
            scaled=signed((din>>(15+sh))+((din>>(14+sh))&1),16)
            expected_sat=max(-128,min(127,scaled))&255
            if int(ad)!=expected_sum:mismatches.append({"cycle":i,"module":"adder","expected":expected_sum,"actual":int(ad)})
            if int(st)!=expected_sat:mismatches.append({"cycle":i,"module":"scale_sat","expected":expected_sat,"actual":int(st)})
    return {"vectors":len(seq),"observed":len([x for x in lines if x.startswith('V ')]),"checked_values":checked,
            "latency_edges":{"multiplier":4,"adder":2,"scale_sat":2},"mismatches":mismatches}


if __name__=="__main__":
    result={"source":"adamgallas/fpga_accelerator_yolov3tiny@6ba312bd220e67a987d3417bacd030db30b15770",
            "multiplier":check_multiplier(),"adder":check_adder(),"adder_candidate":check_adder(True),"scale_sat":check_scale_sat(),"chain_candidate":check_chain(),"continuous_latency":check_continuous_latency()}
    (OUT/"summary.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    print(json.dumps({k:{"vectors":v["vectors"],"observed":v["observed"],"mismatch_count":len(v["mismatches"]),"first_mismatches":v["mismatches"][:3]} for k,v in result.items() if isinstance(v,dict)},indent=2))
    for name,value in result.items():
        if not isinstance(value,dict):continue
        assert value["observed"] == value["vectors"] + (5 if name=="continuous_latency" else 0), name
        expected_errors=4 if name=="adder" else 0
        assert len(value["mismatches"])==expected_errors, (name,len(value["mismatches"]))
