/* Local 3D sedan model: world-space surfaces share the road's perspective.
 * Built once, rendered only while the editor is visible; no network or WebGL dependency. */
(() => {
  'use strict';
  const surfaces=[];
  const face=(points,fill,stroke=null,lineWidth=.5)=>surfaces.push({points,fill,stroke,lineWidth});
  const point=(x,y,z)=>({x,y,z});
  const bodyRings=[
    [-2.35,.78,.67],[-2.13,.94,.82],[-1.50,1.00,.88],[-.50,1.01,.90],
    [.70,1.00,.86],[1.50,.94,.79],[2.16,.83,.66],[2.38,.64,.52]
  ].map(([y,w,h])=>[
    point(-w*.88,y,.23),point(-w,y,.37),point(-w,y,h-.11),point(-w*.82,y,h),
    point(w*.82,y,h),point(w,y,h-.11),point(w,y,.37),point(w*.88,y,.23)
  ]);
  const paint=['#474b50','#74797f','#aeb4bb','#d5d9de','#afb5bd','#74797f','#454a50','#34383d'];
  for(let ring=0;ring<bodyRings.length-1;ring++) for(let edge=0;edge<8;edge++) {
    const next=(edge+1)%8;
    face([bodyRings[ring][edge],bodyRings[ring+1][edge],bodyRings[ring+1][next],bodyRings[ring][next]],paint[edge]);
  }
  face(bodyRings[0],'#7f858d','#454b53');face(bodyRings.at(-1),'#868d96');
  // Four wheels, tire sidewalls, alloy rims and radial spokes.
  for(const side of [-1,1]) for(const y of [-1.45,1.40]) {
    const inner=side*.88,outer=side*1.065,z=.35,radius=.36,segments=18;
    for(let segment=0;segment<segments;segment++) {
      const a=segment*Math.PI*2/segments,b=(segment+1)*Math.PI*2/segments;
      face([point(inner,y+Math.sin(a)*radius,z+Math.cos(a)*radius),point(outer,y+Math.sin(a)*radius,z+Math.cos(a)*radius),
        point(outer,y+Math.sin(b)*radius,z+Math.cos(b)*radius),point(inner,y+Math.sin(b)*radius,z+Math.cos(b)*radius)],segment<6?'#23262a':'#101215');
    }
    const tire=[],rim=[];
    for(let segment=0;segment<segments;segment++) {
      const a=segment*Math.PI*2/segments;
      tire.push(point(outer,y+Math.sin(a)*radius,z+Math.cos(a)*radius));
      rim.push(point(outer+side*.005,y+Math.sin(a)*.245,z+Math.cos(a)*.245));
    }
    face(tire,'#15171a','#080a0c');face(rim,'#707984','#bbc1c8',.4);
    for(let spoke=0;spoke<5;spoke++) {
      const a=spoke*Math.PI*2/5,b=a+.21;
      face([point(outer+side*.01,y,z),point(outer+side*.01,y+Math.sin(a)*.21,z+Math.cos(a)*.21),
        point(outer+side*.01,y+Math.sin(b)*.21,z+Math.cos(b)*.21)],'#c5cad1');
    }
  }
  // Cabin: rear glass, metallic roof, windshield and separate side windows.
  const rearBottom=[point(-.79,-1.35,.9),point(.79,-1.35,.9)];
  const rearTop=[point(-.67,-.72,1.46),point(.67,-.72,1.46)];
  const frontTop=[point(-.65,.34,1.49),point(.65,.34,1.49)];
  const frontBottom=[point(-.8,1.14,.89),point(.8,1.14,.89)];
  face([rearBottom[0],rearTop[0],rearTop[1],rearBottom[1]],'#28343e','#c1c8d0',.65);
  face([rearTop[0],frontTop[0],frontTop[1],rearTop[1]],'#c7cdd4','#e0e4e9',.7);
  face([frontTop[0],frontBottom[0],frontBottom[1],frontTop[1]],'#35454f','#c7ced6',.6);
  // Light reflections on glass, integrated panoramic roof.
  face([point(-.56,-.55,1.475),point(-.54,.16,1.501),point(.54,.16,1.501),point(.56,-.55,1.475)],'#253139','#858f98',.5);
  face([point(-.56,-.48,1.486),point(-.53,.1,1.51),point(-.1,.1,1.51),point(-.34,-.48,1.486)],'#39454e');
  face([point(-.60,.47,1.399),point(-.74,1.02,.985),point(.45,1.02,.985),point(.60,.47,1.399)],'#52616b');
  for(const side of [-1,1]) {
    face([point(side*.81,-1.24,.89),point(side*.69,-.68,1.42),point(side*.67,.30,1.45),point(side*.82,1.02,.9)],'#8d959e','#c4cbd2',.6);
    face([point(side*.81,-1.06,.97),point(side*.699,-.65,1.35),point(side*.686,-.12,1.37),point(side*.82,-.11,.97)],'#202c35','#68737e',.5);
    face([point(side*.82,.0,.97),point(side*.677,.0,1.37),point(side*.675,.25,1.37),point(side*.82,.86,.97)],'#293640','#7e8993',.5);
    // Rear quarter glass, door handles and a metal beltline.
    face([point(side*.805,-1.19,.96),point(side*.72,-.76,1.29),point(side*.77,-1.04,1.02)],'#26333e');
    face([point(side*1.012,-.94,.74),point(side*1.012,-.68,.74),point(side*1.013,-.68,.70),point(side*1.013,-.94,.70)],'#d1d5da');
    face([point(side*1.01,.30,.74),point(side*1.01,.57,.74),point(side*1.011,.57,.70),point(side*1.011,.30,.70)],'#cdd2d7');
    face([point(side*1.02,-1.15,.58),point(side*1.02,1.09,.57),point(side*1.022,1.09,.54),point(side*1.022,-1.15,.55)],'#626b75');
    // Side mirrors with body-colored shell and dark mounting arm.
    face([point(side*.82,.75,.95),point(side*1.17,.78,.92),point(side*1.17,.48,.87),point(side*.84,.48,.9)],'#1c242b');
    face([point(side*.99,.8,1.02),point(side*1.21,.74,.98),point(side*1.19,.5,.96),point(side*.98,.54,1.03)],'#c6cdd5','#65707a',.4);
    // Hood creases and white front LED headlights.
    face([point(side*.50,1.19,.883),point(side*.57,2.00,.708),point(side*.61,2.00,.703),point(side*.55,1.19,.880)],'#bdc4cc');
    face([point(side*.48,2.17,.67),point(side*.78,2.10,.67),point(side*.75,2.24,.52),point(side*.48,2.31,.53)],'#d7e9f1');
    // Red taillight housing and a narrower illuminated strip.
    face([point(side*.36,-2.353,.65),point(side*.75,-2.352,.65),point(side*.75,-2.354,.48),point(side*.36,-2.354,.48)],'#711b23','#3d1418',.5);
    face([point(side*.40,-2.362,.61),point(side*.71,-2.362,.61),point(side*.71,-2.363,.57),point(side*.40,-2.363,.57)],'#ff5969');
  }
  // Rear trunk panel, spoiler edge, license plate, diffuser and exhaust tips.
  face([point(-.67,-2.07,.836),point(.67,-2.07,.836),point(.64,-2.26,.727),point(-.64,-2.26,.727)],'#b9c0c8','#626c76',.6);
  face([point(-.67,-2.10,.843),point(.67,-2.10,.843),point(.67,-2.16,.815),point(-.67,-2.16,.815)],'#dde1e7');
  face([point(-.21,-2.359,.53),point(.21,-2.359,.53),point(.21,-2.360,.42),point(-.21,-2.360,.42)],'#dfe3e7','#4a515b',.5);
  face([point(-.62,-2.364,.32),point(.62,-2.364,.32),point(.55,-2.365,.22),point(-.55,-2.365,.22)],'#20252a');
  for(const side of [-1,1]) face([point(side*.46,-2.371,.29),point(side*.61,-2.371,.29),point(side*.61,-2.372,.24),point(side*.46,-2.372,.24)],'#9aa5ae','#292f35');
  // Precompute painter order for the elevated camera behind the vehicle.
  surfaces.sort((a,b)=>{
    const depth=surface=>surface.points.reduce((sum,p)=>sum+p.y-p.z*.65,0)/surface.points.length;
    return depth(b)-depth(a);
  });
  window.WaypointPreviewCar={
    render(ctx,project,lane,time=0){
      const distance=4.0,bob=Math.sin(time*2.8)*.007;
      const projectPoint=p=>project(lane+p.x,distance+p.y,p.z+bob);
      ctx.save();ctx.shadowBlur=0;ctx.globalAlpha=1;
      // Ground-contact shadow follows the same road projection.
      ctx.beginPath();for(let i=0;i<=32;i++){
        const angle=i*Math.PI/16,p=project(lane+Math.cos(angle)*1.23,distance+Math.sin(angle)*2.62,.01);
        i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y);
      }ctx.closePath();ctx.fillStyle='#0000003d';ctx.fill();
      for(const surface of surfaces){
        ctx.beginPath();surface.points.forEach((vertex,index)=>{const p=projectPoint(vertex);index?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y);});ctx.closePath();
        ctx.fillStyle=surface.fill;ctx.fill();
        if(surface.stroke){ctx.strokeStyle=surface.stroke;ctx.lineWidth=surface.lineWidth;ctx.stroke();}
      }
      ctx.restore();
    }
  };
})();
