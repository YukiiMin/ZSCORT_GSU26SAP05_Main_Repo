const puppeteer = require("puppeteer-core");

const chrome =
  process.env.CHROME ||
  "C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe";

(async () => {
  const browser = await puppeteer.launch({
    executablePath: chrome,
    headless: true,
    args: ["--no-sandbox", "--disable-gpu"]
  });
  const page = await browser.newPage();
  const logs = [];
  page.on("console", (m) => logs.push(m.type() + ": " + m.text()));
  page.on("pageerror", (e) => logs.push("PAGEERROR: " + e.message));
  await page.goto("http://localhost:8080/index.html", {
    waitUntil: "domcontentloaded",
    timeout: 60000
  });
  await new Promise((r) => setTimeout(r, 10000));
  const info = await page.evaluate(() => ({
    text: (document.body.innerText || "").slice(0, 500),
    hasFcl: !!document.querySelector(".sapFFCL"),
    hasList: !!document.querySelector(".sapMList"),
    hasDyn: !!document.querySelector(".sapFDynamicPage"),
    hasTitle: /TR Objects|Transport|Starting/i.test(document.body.innerText || ""),
    kids: document.body.children.length
  }));
  console.log(JSON.stringify(info, null, 2));
  console.log("---RELEVANT LOGS---");
  logs
    .filter((l) => /zscort|error|Error|fail|PAGEERROR/i.test(l))
    .slice(0, 50)
    .forEach((l) => console.log(l));
  await browser.close();
  if (!info.hasTitle && !info.hasList) {
    process.exit(2);
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
