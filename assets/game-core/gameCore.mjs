// Core Rust/WASM; adapter giữ DOM/Three.js và callback RNG/chọn lớp ở trình duyệt.
let engine=null,loading=null,backend='javascript',busy=false;
let context={};const calls={};
const encoder=new TextEncoder(),decoder=new TextDecoder();
export const gameCoreImports={env:{host_random:()=> (context.random??Math.random)(),host_select:(x,y)=>context.select?.(x,y)?1:0}};
export const gameCoreExports=()=>{if(!engine)throw Error('Core Rust chưa tải. Hãy tải lại trò chơi.');return engine;};
export const gameCoreStatus=()=>({backend,calls:{...calls}});
export function installGameCore(exports){
 if(exports.abi_version()!==1||!(exports.memory instanceof WebAssembly.Memory))throw Error('ABI gameplay Rust không phù hợp');
 for(const key of ['alloc','dealloc','run','output_len'])if(typeof exports[key]!=='function')throw Error('Thiếu hàm gameplay Rust');
 engine=exports;backend='rust-wasm';
}
export function disableGameCore(){engine=null;backend='javascript';}
export function gameCore(op,args,callbacks={}){
 if(!engine||busy)return null;
 const bytes=encoder.encode(JSON.stringify({op,args}));if(bytes.length>4*1024*1024)return null;
 const exports=engine;let ptr;let result;
 busy=true;context=callbacks;
 try{
  ptr=exports.alloc(bytes.length);new Uint8Array(exports.memory.buffer,ptr,bytes.length).set(bytes);
  const output=exports.run(ptr,bytes.length);const length=exports.output_len();if(length>16*1024*1024)throw Error('Kết quả gameplay quá lớn');
  result=JSON.parse(decoder.decode(new Uint8Array(exports.memory.buffer,output,length)));
  calls[op]=(calls[op]??0)+1;
 }catch(error){engine=null;backend='javascript-fallback';console.warn('Core gameplay Rust gặp lỗi; thao tác này không chạy được.',error);return null;}
 finally{if(ptr!==undefined)exports.dealloc(ptr,bytes.length);busy=false;context={};}
 if(result.error)throw Error(result.error);
 return result;
}
export function initGameCore({disabled=false,fetcher=globalThis.fetch}={}){
 if(disabled){disableGameCore();return Promise.resolve(backend);}
 if(loading)return loading;
 loading=(async()=>{
  try{
   const response=await fetcher(new URL('./wasm/gameplay_core.wasm?no-inline',import.meta.url),{signal:AbortSignal.timeout(5000)});
   if(!response.ok)throw Error('Không tải được gameplay Rust');
   const {instance}=await WebAssembly.instantiate(await response.arrayBuffer(),gameCoreImports);installGameCore(instance.exports);
  }catch{engine=null;backend='javascript-fallback';}
  return backend;
 })();return loading;
}
