/* app/ui/app.js — the Control Room's frontend.
 *
 * Plain browser JavaScript, no framework and no build step, because this app
 * has to run before npm exists on the machine. Views render to innerHTML from
 * data the API returns; anything that came off disk is escaped first.
 */

const TOKEN = window.API_TOKEN;

const state = {
  view: "dashboard",
  data: null,
  guide: null,
  registry: null,
  docs: null,
  activeDoc: null,
  jobOffset: 0,
  polling: null,
};

/* ------------------------------------------------------------------ utils */

function esc(value) {
  return String(value === null || value === undefined ? "" : value).replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]
  );
}

async function api(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { "X-API-Token": TOKEN, "Content-Type": "application/json", ...(options.headers || {}) },
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      detail = (await res.json()).error || detail;
    } catch (err) {
      /* keep the status text */
    }
    throw new Error(detail);
  }
  return res.json();
}

const el = (id) => document.getElementById(id);
const view = () => el("view");

/* --------------------------------------------------------------- markdown */

/* A small renderer for the documents this repo ships: headings, fenced code,
   tables, lists, quotes, rules, and the inline forms. Everything is escaped
   before any markup is added, so a document can never inject HTML. */
function markdown(src) {
  const lines = src.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let i = 0;

  const inline = (text) =>
    esc(text)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/(^|[\s(])\*([^*\n]+)\*/g, "$1<em>$2</em>")
      .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m, label, href) =>
        /^https?:\/\//.test(href) ? `<a href="${href}" target="_blank" rel="noopener">${label}</a>` : label
      );

  while (i < lines.length) {
    const line = lines[i];

    if (/^```/.test(line)) {
      const body = [];
      i += 1;
      while (i < lines.length && !/^```/.test(lines[i])) body.push(lines[i++]);
      i += 1;
      out.push(`<pre><code>${esc(body.join("\n"))}</code></pre>`);
      continue;
    }
    if (/^\s*$/.test(line)) {
      i += 1;
      continue;
    }
    if (/^#{1,6} /.test(line)) {
      const level = line.match(/^#+/)[0].length;
      out.push(`<h${level}>${inline(line.replace(/^#+ /, ""))}</h${level}>`);
      i += 1;
      continue;
    }
    if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
      out.push("<hr />");
      i += 1;
      continue;
    }
    if (/^\|/.test(line) && /^\|[\s:|-]+\|?\s*$/.test(lines[i + 1] || "")) {
      const cells = (row) =>
        row.replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
      const head = cells(line);
      i += 2;
      const rows = [];
      while (i < lines.length && /^\|/.test(lines[i])) rows.push(cells(lines[i++]));
      out.push(
        `<table><thead><tr>${head.map((h) => `<th>${inline(h)}</th>`).join("")}</tr></thead>` +
          `<tbody>${rows
            .map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join("")}</tr>`)
            .join("")}</tbody></table>`
      );
      continue;
    }
    if (/^\s*([-*+]|\d+\.) /.test(line)) {
      const ordered = /^\s*\d+\./.test(line);
      const items = [];
      while (i < lines.length && /^\s*([-*+]|\d+\.) /.test(lines[i])) {
        items.push(inline(lines[i].replace(/^\s*([-*+]|\d+\.) /, "")));
        i += 1;
      }
      const tag = ordered ? "ol" : "ul";
      out.push(`<${tag}>${items.map((t) => `<li>${t}</li>`).join("")}</${tag}>`);
      continue;
    }
    if (/^> /.test(line)) {
      const body = [];
      while (i < lines.length && /^> /.test(lines[i])) body.push(lines[i++].replace(/^> /, ""));
      out.push(`<blockquote>${inline(body.join(" "))}</blockquote>`);
      continue;
    }

    const para = [];
    while (i < lines.length && !/^\s*$/.test(lines[i]) && !/^(#{1,6} |```|\||> |\s*([-*+]|\d+\.) )/.test(lines[i])) {
      para.push(lines[i++]);
    }
    out.push(`<p>${inline(para.join(" "))}</p>`);
  }
  return out.join("\n");
}

/* ----------------------------------------------------------------- runner */

async function runAction(actionId, opts = {}) {
  const meta = state.guide.actions[actionId];
  if (!meta) return;

  if (meta.confirm && !opts.confirmed) {
    return confirmThenRun(actionId, meta, opts);
  }

  const payload = { action: actionId };
  if (opts.level !== undefined && opts.level !== null) payload.level = opts.level;
  if (meta.confirm) payload.confirm = true;

  let res;
  try {
    res = await api("/api/run", { method: "POST", body: JSON.stringify(payload) });
  } catch (err) {
    openConsole(meta.label, "—");
    el("console-body").textContent = `Could not start: ${err.message}`;
    setBadge("failed");
    return;
  }

  if (res.mode === "terminal") {
    openConsole(meta.label, res.command);
    el("console-body").textContent =
      `Handed over to Terminal.\n\n` +
      `  ${res.command}\n\n` +
      `A Terminal window is now open and running it. Watch it there — that is where\n` +
      `macOS asks for your password and where you can stop it with Ctrl-C.\n\n` +
      `The script this app wrote: ${res.script}\n` +
      `When it finishes, come back and run the verify step.`;
    setBadge("done");
    return;
  }

  state.jobOffset = 0;
  openConsole(meta.label, res.command);
  el("console-body").textContent = "";
  setBadge("running");
  poll();
}

function confirmThenRun(actionId, meta, opts) {
  const level = opts.level;
  el("modal-title").textContent = "This will change your Mac";
  el("modal-body").textContent =
    `${meta.changes} It opens in Terminal so you can see every step and stop it at ` +
    `any time. Nothing else on your Mac is touched.`;
  el("modal-cmd").textContent =
    meta.command + (level !== undefined && level !== null ? ` --level ${level} --yes` : " --yes");
  el("modal").hidden = false;

  const cleanup = () => {
    el("modal").hidden = true;
    el("modal-confirm").onclick = null;
    el("modal-cancel").onclick = null;
  };
  el("modal-cancel").onclick = cleanup;
  el("modal-confirm").onclick = () => {
    cleanup();
    runAction(actionId, { ...opts, confirmed: true });
  };
}

function openConsole(title, command) {
  el("console").hidden = false;
  el("console-title").textContent = title;
  el("console-cmd").textContent = command;
}

function setBadge(kind) {
  const badge = el("console-state");
  badge.className = `badge ${kind}`;
  badge.textContent = kind;
  el("console-stop").disabled = kind !== "running";
}

function classifyLine(line) {
  if (/^\[PASS\]/.test(line)) return "line-pass";
  if (/^\[WARN\]/.test(line) || /^\s+→/.test(line)) return "line-warn";
  if (/^\[FAIL\]/.test(line)) return "line-fail";
  return "";
}

async function poll() {
  clearTimeout(state.polling);
  let job;
  try {
    job = await api(`/api/job?from=${state.jobOffset}`);
  } catch (err) {
    setBadge("failed");
    return;
  }
  if (job.state === "idle") return;

  const body = el("console-body");
  if (job.lines && job.lines.length) {
    const atBottom = body.scrollHeight - body.scrollTop - body.clientHeight < 60;
    for (const line of job.lines) {
      const span = document.createElement("span");
      const cls = classifyLine(line);
      if (cls) span.className = cls;
      span.textContent = line + "\n";
      body.appendChild(span);
    }
    state.jobOffset = job.total;
    if (atBottom) body.scrollTop = body.scrollHeight;
  }

  if (job.state === "running") {
    setBadge("running");
    state.polling = setTimeout(poll, 600);
    return;
  }

  setBadge(job.state === "done" ? "done" : "failed");
  const tail = document.createElement("span");
  tail.className = "muted";
  tail.textContent =
    `\n— finished in ${job.elapsed}s with exit code ${job.exit_code}` +
    (job.truncated ? " (output truncated)" : "") +
    "\n";
  body.appendChild(tail);
  body.scrollTop = body.scrollHeight;
  refresh();
}

/* ------------------------------------------------------------------ views */

const LEVEL_NAMES = ["Emergency", "Base", "Full", "Maximum"];

function renderDashboard() {
  const m = state.data.machine;
  const checks = (state.data.counts || {}).doctor_checks || 42;
  const c = state.data.currency || {};
  const reached =
    m.level_reached < 0
      ? "not started"
      : `Level ${m.level_reached} · ${LEVEL_NAMES[m.level_reached]}`;

  const tested = m.macos && !m.macos.startsWith(m.tested_on);

  view().innerHTML = `
    <h1>Where this Mac stands</h1>
    <p class="lede">A quick look at the machine. The tiles below are a probe, not a
      verdict — they check whether a handful of marker tools exist. The honest
      answer comes from the verify step in the guide, which runs all ${esc(checks)} checks.</p>

    <div class="tiles">
      <div class="tile">
        <div class="tile-label">Setup reached</div>
        <div class="tile-value">${esc(reached)}</div>
        <div class="tile-note">${m.level_reached < 3 ? "You can go further." : "Everything installed."}</div>
      </div>
      <div class="tile">
        <div class="tile-label">macOS</div>
        <div class="tile-value">${esc(m.macos)}</div>
        <div class="tile-note">${esc(m.arch)} · tested on ${esc(m.tested_on)}</div>
      </div>
      <div class="tile">
        <div class="tile-label">Tools tracked</div>
        <div class="tile-value">${esc(state.data.registry_count)}</div>
        <div class="tile-note">in the registry</div>
      </div>
      <div class="tile">
        <div class="tile-label">Drift found</div>
        <div class="tile-value">${c.drift_found ? "yes" : "no"}</div>
        <div class="tile-note">${c.last_check ? `checked ${esc(c.last_check.slice(0, 10))}` : "never checked"}</div>
      </div>
    </div>

    ${
      tested
        ? `<div class="note"><strong>This macOS version is untested.</strong> The setup was
             distilled from macOS ${esc(m.tested_on)} and has only been run there. Version
             ${esc(m.macos)} is expected to work but nobody has verified it. Use the preview
             step before any real run.</div>`
        : ""
    }

    <h2>What was found on this machine</h2>
    <div class="probe">
      ${m.tools
        .map(
          (t) => `<div class="probe-item">
            <span class="dot ${t.present ? "on" : "off"}"></span>
            <span>${esc(t.name)}</span>
            <span class="probe-level">L${t.level}</span>
          </div>`
        )
        .join("")}
    </div>

    <h2>Do this next</h2>
    <div class="card">
      <p style="margin:0 0 12px;color:var(--text-dim)">
        ${
          m.level_reached < 0
            ? "Nothing is set up yet. Start with the readiness check — it changes nothing."
            : m.first_light_ready
              ? "There is an AI model on this Mac now. Verify the setup, then run First " +
                "Light and watch it read real files and write something back — that is " +
                "the whole point of everything above."
              : "Verify what is already here, then continue with the next level in the guide."
        }
      </p>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        ${
          m.first_light_ready
            ? `<button class="btn btn-primary" data-run="first-light">Run First Light</button>
               <button class="btn" data-run="doctor">Verify the setup</button>`
            : `<button class="btn btn-primary" data-run="check-readiness">Check this Mac</button>
               <button class="btn" data-run="doctor">Verify the setup</button>`
        }
        <button class="btn btn-quiet" data-goto="guide">Open the guide</button>
      </div>
    </div>`;
}

function renderGuide() {
  const steps = state.guide.steps;
  view().innerHTML = `
    <h1>Step by step</h1>
    <p class="lede">Top to bottom, in order. Every step says what it does and whether it
      changes anything. Preview first, then run, then verify — and nothing installs
      itself: the run step hands over to Terminal, where you watch it happen.</p>

    <div class="note"><strong>You cannot break this by re-running it.</strong> Every level
      can be run again safely; steps that are already done are skipped. If you are
      unsure where you are, run the verify step.</div>

    ${steps
      .map((step, index) => {
        const action = state.guide.actions[step.action];
        const safe = action.mode === "inline";
        return `<div class="step">
          <div class="step-head">
            <span class="step-num">${String(index + 1).padStart(2, "0")}</span>
            <span class="step-title">${esc(step.title)}</span>
          </div>
          <div class="step-body">${esc(step.body)}</div>
          <div class="step-meta">Runs <code>${esc(action.command)}${
            step.level !== undefined ? ` --level ${step.level}` : ""
          }</code> · ${esc(action.changes)}</div>
          <div class="step-actions">
            <button class="btn ${safe ? "" : "btn-danger"}"
                    data-run="${esc(step.action)}"
                    ${step.level !== undefined ? `data-level="${step.level}"` : ""}>
              ${esc(action.label)}
            </button>
            <span class="tag ${safe ? "safe" : "changes"}">${safe ? "changes nothing on this Mac" : "changes your Mac"}</span>
          </div>
        </div>`;
      })
      .join("")}`;
}

function renderRegistry() {
  const entries = state.registry.entries;
  const categories = [...new Set(entries.map((e) => e.category))].sort();
  view().innerHTML = `
    <h1>Everything this setup installs</h1>
    <p class="lede">The tool registry is the single source of truth: the package lists are
      derived from it, not the other way round. <strong>Level</strong> says when a tool
      arrives, <strong>status</strong> says where it is in its life — a tool marked
      <em>sunset</em> is on its way out and is never installed.</p>

    <div class="filters">
      <input id="reg-search" type="search" placeholder="Search name, id or reason…" />
      <select id="reg-category"><option value="">All categories</option>
        ${categories.map((c) => `<option value="${esc(c)}">${esc(c)}</option>`).join("")}</select>
      <select id="reg-level"><option value="">All levels</option>
        ${[0, 1, 2, 3].map((l) => `<option value="${l}">Level ${l}</option>`).join("")}</select>
      <select id="reg-status"><option value="">All statuses</option>
        ${["active", "candidate", "deprecated", "sunset"]
          .map((s) => `<option value="${s}">${s}</option>`)
          .join("")}</select>
    </div>

    <div class="table-wrap"><table>
      <thead><tr>
        <th>Tool</th><th class="mono">id</th><th>Category</th><th>From</th>
        <th>Level</th><th>Status</th><th class="mono">Version</th><th>Why it is here</th>
      </tr></thead>
      <tbody id="reg-body"></tbody>
    </table></div>
    <p class="muted" style="margin-top:10px;font-size:12.5px" id="reg-count"></p>`;

  const draw = () => {
    const q = el("reg-search").value.trim().toLowerCase();
    const cat = el("reg-category").value;
    const lvl = el("reg-level").value;
    const st = el("reg-status").value;
    const rows = entries.filter(
      (e) =>
        (!cat || e.category === cat) &&
        (!lvl || String(e.level) === lvl) &&
        (!st || e.status === st) &&
        (!q ||
          `${e.id} ${e.name} ${e.why || ""}`.toLowerCase().includes(q))
    );
    el("reg-body").innerHTML = rows
      .map(
        (e) => `<tr>
          <td>${esc(e.name)}</td>
          <td class="mono muted">${esc(e.id)}</td>
          <td>${esc(e.category)}</td>
          <td class="mono muted">${esc(e.source)}</td>
          <td class="mono">${esc(e.level)}</td>
          <td><span class="pill ${esc(e.status)}">${esc(e.status)}</span></td>
          <td class="mono muted">${esc(e.version_seen || "—")}</td>
          <td class="wrap">${esc(e.why || "")}${
            e.sunset ? ` <span class="muted">(retires ${esc(e.sunset)})</span>` : ""
          }</td>
        </tr>`
      )
      .join("");
    el("reg-count").textContent = `${rows.length} of ${entries.length} tools shown.`;
  };

  ["reg-search", "reg-category", "reg-level", "reg-status"].forEach((id) => {
    el(id).addEventListener("input", draw);
  });
  draw();
}

function renderCurrency() {
  const c = state.data.currency || {};
  const entries = (state.registry && state.registry.entries) || [];
  const attention = entries.filter((e) => e.status === "deprecated" || e.status === "sunset");
  const candidates = entries.filter((e) => e.status === "candidate");

  view().innerHTML = `
    <h1>What has gone out of date</h1>
    <p class="lede">A setup is correct on the day it is written and never again. This page
      shows what has drifted since. It only ever <em>reports</em> — nothing here installs,
      removes, or retires a tool. Those are decisions a person makes.</p>

    <div class="tiles">
      <div class="tile"><div class="tile-label">Last checked</div>
        <div class="tile-value">${esc(c.last_check ? c.last_check.slice(0, 10) : "never")}</div>
        <div class="tile-note">${esc(c.checked_count || 0)} tools checked</div></div>
      <div class="tile"><div class="tile-label">Updates available</div>
        <div class="tile-value">${esc(c.update_available || 0)}</div></div>
      <div class="tile"><div class="tile-label">Looks abandoned</div>
        <div class="tile-value">${esc(c.sunset_candidate || 0)}</div></div>
      <div class="tile"><div class="tile-label">Review due</div>
        <div class="tile-value">${esc(c.review_due || 0)}</div></div>
    </div>

    ${
      c.check_complete === false
        ? `<div class="note"><strong>The last check did not complete.</strong> The numbers above
             are from a partial run, so treat them as a floor, not a total.</div>`
        : ""
    }

    <div class="card" style="margin-top:16px">
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button class="btn btn-primary" data-run="currency-check">Check for tool drift</button>
        <button class="btn" data-run="registry-consistency">Check the registry</button>
      </div>
      <p class="muted" style="margin:12px 0 0;font-size:12.5px">
        The drift check reaches out to the internet and takes a while. The registry check
        works offline and only compares the repo against itself.</p>
    </div>

    <h2>On their way out (${attention.length})</h2>
    ${
      attention.length
        ? `<div class="table-wrap"><table>
            <thead><tr><th>Tool</th><th>Status</th><th>Retires</th><th>Replaced by</th><th>Why</th></tr></thead>
            <tbody>${attention
              .map(
                (e) => `<tr><td>${esc(e.name)}</td>
                  <td><span class="pill ${esc(e.status)}">${esc(e.status)}</span></td>
                  <td class="mono muted">${esc(e.sunset || "—")}</td>
                  <td class="mono muted">${esc(e.replaced_by || "—")}</td>
                  <td class="wrap">${esc(e.why || "")}</td></tr>`
              )
              .join("")}</tbody></table></div>`
        : `<p class="muted">Nothing is being retired right now.</p>`
    }

    <h2>Waiting for a decision (${candidates.length})</h2>
    <p class="muted" style="font-size:13.5px">Candidates are never installed automatically.
      Someone has to decide whether each one belongs in this setup.</p>
    ${
      candidates.length
        ? `<div class="table-wrap"><table>
            <thead><tr><th>Tool</th><th>Category</th><th>Level</th><th>Why it was noted</th></tr></thead>
            <tbody>${candidates
              .map(
                (e) => `<tr><td>${esc(e.name)}</td><td>${esc(e.category)}</td>
                  <td class="mono">${esc(e.level)}</td><td class="wrap">${esc(e.why || "")}</td></tr>`
              )
              .join("")}</tbody></table></div>`
        : `<p class="muted">No open candidates.</p>`
    }`;
}

function renderMigration() {
  view().innerHTML = `
    <h1>Old Mac to new Mac</h1>
    <p class="lede">Moving machines is two jobs: capture what the old one has, then check
      what the new one is still missing. Both are read-only — the export never touches
      keys, tokens or the contents of any <code>.env</code> file, only names and places.</p>

    <div class="step">
      <div class="step-head"><span class="step-num">01</span>
        <span class="step-title">On the OLD Mac — export the machine</span></div>
      <div class="step-body">Captures versions, installed apps, your repositories and their
        state, Docker stacks and local models into a profile file. Run this while the old
        machine is still working.</div>
      <div class="step-meta">Writes <code>local/status-quo/</code> · nothing outside the repo</div>
      <div class="step-actions">
        <button class="btn" data-run="status-quo">Export this machine</button>
        <span class="tag safe">changes nothing on this Mac</span>
      </div>
    </div>

    <div class="step">
      <div class="step-head"><span class="step-num">02</span>
        <span class="step-title">Carry the profile over</span></div>
      <div class="step-body">Copy <code>profile.json</code> from <code>local/status-quo/</code>
        to the new Mac by hand — USB stick, AirDrop, a private note. It describes your
        machine, so it does not belong in a public place. This step stays manual on
        purpose.</div>
    </div>

    <div class="step">
      <div class="step-head"><span class="step-num">03</span>
        <span class="step-title">On the NEW Mac — set it up</span></div>
      <div class="step-body">Work through the guide as normal. Come back here once the level
        you want is installed.</div>
      <div class="step-actions"><button class="btn btn-quiet" data-goto="guide">Open the guide</button></div>
    </div>

    <div class="step">
      <div class="step-head"><span class="step-num">04</span>
        <span class="step-title">On the NEW Mac — compare</span></div>
      <div class="step-body">Reads the profile and lists what is still missing here, which
        versions differ, and what was dropped on purpose because the registry retired it.</div>
      <div class="step-meta">Writes <code>local/migration-diff.md</code> · nothing outside the repo</div>
      <div class="step-actions">
        <button class="btn" data-run="migration-diff">Compare against the old machine</button>
        <span class="tag safe">changes nothing on this Mac</span>
      </div>
    </div>

    <div class="note"><strong>Secrets never travel in the profile.</strong> Passwords, keys and
      tokens move separately through your password vault. The Secrets document under Docs
      explains that path.</div>

    <p class="muted" style="margin-top:18px;font-size:13.5px">
      The full walkthrough, including what the export cannot capture, is in the
      <button class="btn btn-quiet" data-doc="migration">Machine migration</button> document.</p>`;
}

async function renderDocs() {
  if (!state.docs) state.docs = await api("/api/docs");
  const active = state.activeDoc || state.docs.docs.find((d) => d.available).id;
  state.activeDoc = active;

  view().innerHTML = `
    <h1>The manual, in here</h1>
    <p class="lede">The repository's documents, rendered so you do not have to go looking
      for files. These are the same documents that live next to the code.</p>
    <div class="doc-list">
      ${state.docs.docs
        .filter((d) => d.available)
        .map(
          (d) =>
            `<button class="btn ${d.id === active ? "active" : ""}" data-doc="${esc(d.id)}">${esc(d.title)}</button>`
        )
        .join("")}
    </div>
    <div class="markdown" id="doc-body"><p class="spinner">Loading…</p></div>`;

  try {
    const doc = await api(`/api/docs?id=${encodeURIComponent(active)}`);
    el("doc-body").innerHTML = markdown(doc.markdown);
  } catch (err) {
    el("doc-body").innerHTML = `<p class="muted">Could not load: ${esc(err.message)}</p>`;
  }
}

/* ------------------------------------------------------------------ shell */

const VIEWS = {
  dashboard: renderDashboard,
  guide: renderGuide,
  registry: renderRegistry,
  currency: renderCurrency,
  migration: renderMigration,
  docs: renderDocs,
};

async function show(name) {
  state.view = name;
  document.querySelectorAll(".nav-item").forEach((b) => {
    b.classList.toggle("active", b.dataset.view === name);
  });
  if ((name === "registry" || name === "currency") && !state.registry) {
    view().innerHTML = `<p class="spinner">Reading the registry…</p>`;
    state.registry = await api("/api/registry");
  }
  await VIEWS[name]();
}

async function refresh() {
  state.data = await api("/api/state");
  el("foot-version").textContent = `v${state.data.machine.repo_version}`;
  if (state.view === "dashboard" || state.view === "currency") await show(state.view);
}

document.addEventListener("click", (event) => {
  const nav = event.target.closest(".nav-item");
  if (nav) return void show(nav.dataset.view);

  const goto = event.target.closest("[data-goto]");
  if (goto) return void show(goto.dataset.goto);

  const doc = event.target.closest("[data-doc]");
  if (doc) {
    state.activeDoc = doc.dataset.doc;
    return void show("docs");
  }

  const run = event.target.closest("[data-run]");
  if (run) {
    const level = run.dataset.level === undefined ? undefined : Number(run.dataset.level);
    return void runAction(run.dataset.run, { level });
  }
});

el("console-close").addEventListener("click", () => {
  el("console").hidden = true;
});
el("console-stop").addEventListener("click", async () => {
  try {
    await api("/api/job/stop", { method: "POST", body: "{}" });
  } catch (err) {
    /* already finished */
  }
});

(async function boot() {
  try {
    state.guide = await api("/api/guide");
    await refresh();
    await show("dashboard");
  } catch (err) {
    view().innerHTML =
      `<h1>Could not reach the app</h1><p class="lede">${esc(err.message)}. ` +
      `Stop it with Ctrl-C in the Terminal window and run <code>./start.sh</code> again.</p>`;
  }
})();
