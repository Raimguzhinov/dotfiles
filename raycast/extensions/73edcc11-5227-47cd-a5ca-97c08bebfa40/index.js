var C=Object.defineProperty;var I=Object.getOwnPropertyDescriptor;var X=Object.getOwnPropertyNames;var k=Object.prototype.hasOwnProperty;var U=t=>C(t,"__esModule",{value:!0});var E=(t,i)=>{for(var s in i)C(t,s,{get:i[s],enumerable:!0})},B=(t,i,s,r)=>{if(i&&typeof i=="object"||typeof i=="function")for(let a of X(i))!k.call(t,a)&&(s||a!=="default")&&C(t,a,{get:()=>i[a],enumerable:!(r=I(i,a))||r.enumerable});return t};var M=(t=>(i,s)=>t&&t.get(i)||(s=B(U({}),i,1),t&&t.set(i,s),s))(typeof WeakMap!="undefined"?new WeakMap:0);var q={};E(q,{copyOTP:()=>g,copyPassword:()=>y,default:()=>b,pasteOTP:()=>A,pastePassword:()=>P});var o=require("@raycast/api"),w=require("react");var O=require("os"),D=require("child_process");var S=require("url"),W=t=>t[0].toUpperCase().concat(t.slice(1)),T=t=>t==="url"?t.toUpperCase():W(t),u=t=>t.endsWith("/"),v=t=>t.sort((i,s)=>u(i)&&!u(s)?-1:0),x=t=>{try{return/^http[s]?:/.test(new S.URL(t).protocol)}catch{return!1}};function f(t){return new Promise((i,s)=>{let r=(0,D.spawn)("gopass",t,{env:{HOME:(0,O.homedir)(),PATH:["/bin","/usr/bin","/usr/local/bin","/usr/local/MacGPG2/bin","/opt/homebrew/bin"].join(":")}});r.on("error",s);let a=[];r.stderr.on("data",l=>a.push(l)),r.stderr.on("end",()=>a.length>0&&s(a.join("")));let n=[];r.stdout.on("data",l=>n.push(l)),r.stdout.on("end",()=>i(n.join("")))})}async function H({limit:t=-1,prefix:i="",directoriesFirst:s=!1,stripPrefix:r=!1}={}){return await f(["list",`--limit=${t}`,"--flat",`--strip-prefix=${r}`,i]).then(a=>a.split(`
`)).then(a=>a.filter(n=>n.length)).then(a=>s?v(a):a)}async function $(t){return f(["show","--password",t])}async function j(t){return f(["otp","--password",t])}async function z(t){await f(["show","--clip",t])}async function R(t){return await f(["show",t]).then(i=>i.split(`
`).slice(1)).then(i=>i.filter(s=>s.includes(":")))}var d={list:H,password:$,clip:z,show:R,otp:j};var e=require("@raycast/api"),h=require("react");async function G(t,i){await e.Clipboard.copy(i),await(0,e.closeMainWindow)(),await(0,e.showHUD)(`${t} copied`)}async function J(t,i){await(0,e.showHUD)(`${t} pasted`),await e.Clipboard.paste(i),await(0,e.closeMainWindow)()}function L({entry:t}){let[i,s]=(0,h.useState)([]),[r,a]=(0,h.useState)(!0);return(0,h.useEffect)(()=>{d.show(t).then(s).catch(async n=>{console.error(n),await(0,e.showToast)({title:"Could not load passwords",style:e.Toast.Style.Failure})}).finally(()=>a(!1))},[]),_jsx(e.List,{isLoading:r},_jsx(e.List.Section,{title:"/"+t},!r&&_jsx(e.List.Item,{title:"Password",subtitle:"*****************",actions:_jsx(e.ActionPanel,null,_jsx(e.Action,{title:"Copy to Clipboard",icon:e.Icon.Clipboard,onAction:()=>y(t)}),_jsx(e.Action,{title:"Paste to Active App",icon:e.Icon.Document,onAction:()=>P(t)}))}),i.filter(n=>n.startsWith("otpauth:")).map((n,l)=>_jsx(e.List.Item,{key:l,title:"OTP code",subtitle:"XXXXXX",actions:_jsx(e.ActionPanel,null,_jsx(e.Action,{title:"Copy to Clipboard",icon:e.Icon.Clipboard,onAction:()=>g(t)}),_jsx(e.Action,{title:"Paste to Active App",icon:e.Icon.Document,onAction:()=>A(t)}))})),i.filter(n=>!n.startsWith("otpauth:")).map((n,l)=>{let[c,...m]=n.split(": "),p=m.join(": ");return _jsx(e.List.Item,{key:l,title:T(c),subtitle:p,actions:_jsx(e.ActionPanel,null,x(p)&&_jsx(e.Action.OpenInBrowser,{url:p}),_jsx(e.Action,{title:"Copy to Clipboard",icon:e.Icon.Clipboard,onAction:()=>G(c,p)}),_jsx(e.Action,{title:"Paste to Active App",icon:e.Icon.Document,onAction:()=>J(c,p)}))})})))}async function y(t){try{let i=await(0,o.showToast)({title:"Copying password",style:o.Toast.Style.Animated});await d.clip(t),await i.hide(),await(0,o.closeMainWindow)(),await(0,o.showHUD)("Password copied")}catch(i){console.error(i),await(0,o.showToast)({title:"Could not copy password",style:o.Toast.Style.Failure})}}async function P(t){try{let i=await(0,o.showToast)({title:"Pasting password",style:o.Toast.Style.Animated}),s=await d.password(t);await o.Clipboard.paste(s),await i.hide(),await(0,o.closeMainWindow)(),await(0,o.showHUD)("Password pasted")}catch(i){console.error(i),await(0,o.showToast)({title:"Could not paste password",style:o.Toast.Style.Failure})}}async function g(t){try{let i=await(0,o.showToast)({title:"Copying OTP",style:o.Toast.Style.Animated}),s=await d.otp(t);await o.Clipboard.copy(s),await i.hide(),await(0,o.closeMainWindow)(),await(0,o.showHUD)("OTP copied")}catch(i){console.error(i),await(0,o.showToast)({title:"Could not copy OTP code",style:o.Toast.Style.Failure})}}async function A(t){try{let i=await(0,o.showToast)({title:"Pasting OTP",style:o.Toast.Style.Animated}),s=await d.otp(t);await o.Clipboard.paste(s),await i.hide(),await(0,o.closeMainWindow)(),await(0,o.showHUD)("OTP pasted")}catch(i){console.error(i),await(0,o.showToast)({title:"Could not paste OTP code",style:o.Toast.Style.Failure})}}var V=t=>_jsx(_jsxFragment,null,_jsx(o.Action,{title:"Copy Password to Clipboard",icon:o.Icon.Clipboard,onAction:()=>y(t)}),_jsx(o.Action,{title:"Paste Password to Active App",icon:o.Icon.Document,onAction:()=>P(t),shortcut:{modifiers:["cmd","shift"],key:"enter"}}),_jsx(o.Action,{title:"Copy OTP Code to Clipboard",icon:o.Icon.Clipboard,onAction:()=>g(t),shortcut:{modifiers:["cmd"],key:"o"}}),_jsx(o.Action,{title:"Paste OTP Code to Active App",icon:o.Icon.Document,onAction:()=>A(t),shortcut:{modifiers:["cmd","shift"],key:"o"}})),F=t=>u(t)?o.Icon.Folder:o.Icon.Key,K=t=>u(t)?_jsx(b,{prefix:t}):_jsx(L,{entry:t});function b({prefix:t=""}){let[i,s]=(0,w.useState)([]),[r,a]=(0,w.useState)(!0),[n,l]=(0,w.useState)("");return(0,w.useEffect)(()=>{d.list({limit:n?-1:0,prefix:t,directoriesFirst:!0,stripPrefix:!0}).then(c=>c.filter(m=>m.toLowerCase().includes(n.toLowerCase()))).then(s).catch(async c=>{console.error(c),await(0,o.showToast)({title:"Could not load passwords",style:o.Toast.Style.Failure})}).finally(()=>a(!1))},[n]),_jsx(o.List,{isLoading:r,enableFiltering:!1,onSearchTextChange:l},_jsx(o.List.Section,{title:n?"Results":"/"+t,subtitle:n&&String(i.length)},i.map((c,m)=>{let p=t+c;return _jsx(o.List.Item,{key:m,title:c,icon:F(c),accessories:[{icon:o.Icon.ChevronRight}],actions:_jsx(o.ActionPanel,null,_jsx(o.Action.Push,{title:"Show Details",icon:F(c),target:K(p)}),!u(c)&&V(p))})})))}module.exports=M(q);0&&(module.exports={copyOTP,copyPassword,pasteOTP,pastePassword});