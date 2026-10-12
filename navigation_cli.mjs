import fs from 'node:fs';
import {gameCore, gameCoreImports, installGameCore} from './assets/game-core/gameCore.mjs';

const data=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const request=JSON.parse(Buffer.from(process.argv[3],'base64').toString('utf8'));
const {instance}=await WebAssembly.instantiate(fs.readFileSync(new URL('./assets/game-core/gameplay_core.wasm',import.meta.url)),gameCoreImports);
installGameCore(instance.exports);
gameCore('world.init',data.nav);
gameCore('world.ready',null);
if(data.solid)gameCore('solid.set',data.solid);
gameCore('world.restore',{player:{x:request.from[0],z:request.from[1],roomId:null}});
process.stdout.write(JSON.stringify(gameCore('world.walkTo',{x:request.to[0],z:request.to[1]})?.value??[]));
