const http = require("http");

function get(p) {
  return new Promise((res, rej) => {
    http
      .get("http://localhost:8080" + p, (r) => {
        let d = "";
        r.on("data", (c) => (d += c));
        r.on("end", () => res(d));
      })
      .on("error", rej);
  });
}

(async () => {
  const app = await get("/view/App.view.xml");
  console.log("has beginMaster", app.includes("beginMaster"));
  console.log("has Master viewName", app.includes("view.Master"));
  const c = await get("/Component.js");
  console.log("has broken byId guard", c.includes('byId("fcl")'));
  console.log("has router initialized log", c.includes("router initialized"));
  const m = JSON.parse(await get("/manifest.json"));
  console.log("master route", JSON.stringify(m["sap.ui5"].routing.routes[0]));
  console.log("detail target", JSON.stringify(m["sap.ui5"].routing.routes[1].target));
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
