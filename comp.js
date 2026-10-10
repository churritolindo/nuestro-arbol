const IMG_MAXLADO = 1600;    // el lado más largo se limita a esto (px)
const IMG_CALIDAD = 0.82;    // calidad del JPEG (0 a 1)
function _esImagenComprimible(file){
  return !!(file && file.type && file.type.indexOf("image/")===0 && file.type!=="image/gif");
}
// Devuelve {blob, ext, type}. Si no es imagen, no la puede encoger o no mejora, devuelve el original.
function comprimirImagen(file){
  return new Promise(function(resolve){
    if(!_esImagenComprimible(file)){ resolve({blob:file, ext:null, type:file.type}); return; }
    try{
      const url=URL.createObjectURL(file);
      const img=new Image();
      img.onload=function(){
        try{
          let w=img.naturalWidth||img.width, h=img.naturalHeight||img.height;
          const lado=Math.max(w,h);
          const esc = lado>IMG_MAXLADO ? IMG_MAXLADO/lado : 1;
          const nw=Math.max(1,Math.round(w*esc)), nh=Math.max(1,Math.round(h*esc));
          const c=document.createElement("canvas"); c.width=nw; c.height=nh;
          const ctx=c.getContext("2d");
          ctx.fillStyle="#fff"; ctx.fillRect(0,0,nw,nh);   // fondo blanco por si la imagen es transparente
          ctx.drawImage(img,0,0,nw,nh);
          URL.revokeObjectURL(url);
          c.toBlob(function(blob){
            if(blob && blob.size < file.size) resolve({blob:blob, ext:"jpg", type:"image/jpeg"});
            else resolve({blob:file, ext:null, type:file.type});   // si no mejora, dejamos el original
          }, "image/jpeg", IMG_CALIDAD);
        }catch(e){ try{URL.revokeObjectURL(url);}catch(_ ){} resolve({blob:file, ext:null, type:file.type}); }
      };
      img.onerror=function(){ try{URL.revokeObjectURL(url);}catch(_ ){} resolve({blob:file, ext:null, type:file.type}); };
      img.src=url;
    }catch(e){ resolve({blob:file, ext:null, type:file.type}); }
  });
}
