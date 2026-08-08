const puppeteer = require("puppeteer-core");

const chrome =
  process.env.CHROME ||
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";

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
    text: (document.body.innerText || "").slice(0, 600),
    hasFcl: !!document.querySelector(".sapFFCL"),
    hasTitle: /Object Search|TR Search|SCORT|Transport/i.test(document.body.innerText || "")
  }));
  console.log(JSON.stringify(info, null, 2));
  console.log("---RELEVANT LOGS---");
  logs
    .filter((l) => /zscort|error|Error|fail|PAGEERROR|fcl/i.test(l))
    .slice(0, 40)
    .forEach((l) => console.log(l));
  await browser.close();
  if (!info.hasTitle && !info.hasFcl) {
    process.exit(2);
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
