from pathlib import Path
import random, json, subprocess
D=Path(__file__).resolve().parent
ROOT=D.parents[2]
r=random.Random(20261013)
rows=[]; pipeline=[None]*4; prevq=0; prevvalid=0
for t in range(1200):
 rst=int(t in (0,1,30,31,403,801)); ce=int(t<20 or r.random()>.23); valid=int(t<20 or r.random()>.2)
 a=[r.randint(-128,127) for _ in range(9)]; b=[r.randint(-128,127) for _ in range(9)]; bias=r.randint(-50000,50000)
 if t<20:
  a=[[-128,127,-128,127][t%4]]*9;b=[[-128,127,127,-128][t%4]]*9
  bias=[0,2147483647,-2147483648,32767,-32769][t%5]
 if 20<=t<30:
  ce=1;valid=1;a=[-128]*9;b=[-128 if t%2 else 127]*9
  bias=-sum(x*y for x,y in zip(a,b)) + [0,255,256,-1,-256,32767,32768,-32768,-32769,16384][t-20]
 value=max(-128,min(127,(sum(x*y for x,y in zip(a,b))+bias)//256))
 if rst: pipeline=[None]*4;prevq=0;prevvalid=0
 elif ce:
  pipeline=[(valid,value)]+pipeline[:3]
  prevvalid,prevq=pipeline[3] if pipeline[3] is not None else (0,0)
 # invalid q ignored, hold tested when previous valid remains asserted.
 pack=lambda xs: sum((v&255)<<(8*i) for i,v in enumerate(xs))
 rows.append((rst,ce,valid,pack(a),pack(b),bias&0xffffffff,prevvalid,prevq&255))
(D/'vectors.txt').write_text(''.join(f'{a} {b} {c} {d:018x} {e:018x} {f:08x} {g} {h:02x}\n' for a,b,c,d,e,f,g,h in rows))
(D/'vectors.json').write_text(json.dumps({'seed':20261013,'cycles':len(rows),'rows':rows}))
tb=r'''module tb;
reg clk=0;always #5 clk=~clk;
reg rst,ce,iv;reg [71:0] a,b;reg signed [31:0] bias;
wire ov;wire signed [7:0] q;reg ev;reg [7:0] eq;
integer f,n,t=0,checked=0;
int8_core dut(clk,rst,ce,iv,a,b,bias,ov,q);
initial begin
f=$fopen("vectors.txt","r");
while(!$feof(f)) begin
 @(negedge clk);n=$fscanf(f,"%d %d %d %h %h %h %d %h\n",rst,ce,iv,a,b,bias,ev,eq);
 if(n==8) begin
 @(posedge clk);#1;
 if(ov!==ev || (ev && q!==eq) || (rst && q!==0)) begin
 $display("FAIL cycle=%0d ov=%d ev=%d q=%d eq=%d",t,ov,ev,q,$signed(eq));$fatal(1);
 end
 t=t+1;if(ev)checked=checked+1;
 end
end
$display("PASS cycles=%0d valid_or_held_checks=%0d reset/stall/continuous/fullscale",t,checked);$finish;
end
endmodule
'''
(D/'tb.v').write_text(tb)
def run(args):
 p=subprocess.run([str(x) for x in args],cwd=D,text=True,capture_output=True)
 with (D/'simulation.log').open('a') as f:f.write('COMMAND '+str(args)+'\n'+p.stdout+p.stderr)
 if p.returncode:raise SystemExit(p.returncode)
 print(p.stdout,p.stderr)
(D/'simulation.log').write_text('Python exact integer golden; shift floor, signed INT32 bias extended to 33 bits.\n')
run([ROOT/'.tools/iverilog/bin/iverilog.exe','-g2005-sv','-Wall','-s','tb','-o','sim.vvp','int8_core.v','tb.v'])
run([ROOT/'.tools/iverilog/bin/vvp.exe','sim.vvp'])
