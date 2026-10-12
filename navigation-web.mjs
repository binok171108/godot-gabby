import {gameCore, initGameCore} from './core/gameCore.js';

window.gabbyNavigation={ready:false,error:null};
try {
  const data=await fetch('./core/navigation.json').then(response=>{
    if(!response.ok)throw Error('Không tải được dữ liệu bản đồ');
    return response.json();
  });
  const backend=await initGameCore({fetcher:()=>fetch('./core/gameplay_core.wasm')});
  if(backend!=='rust-wasm')throw Error('Không mở được lõi Rust gốc');
  gameCore('world.init',data.nav);
  gameCore('world.ready',null);
  if(data.solid)gameCore('solid.set',data.solid);
  window.gabbyNavigation.path=request=>{
    gameCore('world.restore',{player:{x:request.from[0],z:request.from[1],roomId:null}});
    const path=gameCore('world.walkTo',{x:request.to[0],z:request.to[1]})?.value??[];
    gameCore('world.walkTo',{});
    return path;
  };
  window.gabbyNavigation.ready=true;
} catch(error) {
  window.gabbyNavigation.error=String(error);
  console.error(error);
}
