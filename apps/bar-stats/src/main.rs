// Modules Waybar CPU, mémoire et température, résidents: `bar-stats cpu|mem|temp` écrit une ligne JSON par intervalle
// (module sans "interval" dans la config Waybar). Lit /proc et /sys directement, sans lancer top, ps ni awk.
// Même sortie que l'ancien `bar-status cpu|mem|temp`. Se termine quand Waybar ferme le tuyau.
use std::{collections::HashMap, env, fs, io::Write, process, thread, time::{Duration, Instant}};

struct Proc {
    name: String,
    ticks: u64, // utime + stime
    rss_kb: u64,
}

fn procs(page_kb: u64) -> HashMap<u32, Proc> {
    let mut out = HashMap::new();
    let Ok(dir) = fs::read_dir("/proc") else { return out };
    for e in dir.flatten() {
        let Some(pid) = e.file_name().to_str().and_then(|s| s.parse::<u32>().ok()) else { continue };
        let Ok(stat) = fs::read_to_string(format!("/proc/{pid}/stat")) else { continue };
        // nom entre la première « ( » et la dernière « ) » (il peut contenir des espaces ou des parenthèses)
        let (Some(a), Some(b)) = (stat.find('('), stat.rfind(')')) else { continue };
        let f: Vec<&str> = stat[b + 2..].split_whitespace().collect();
        if f.len() < 22 {
            continue;
        }
        let n = |i: usize| f[i].parse::<u64>().unwrap_or(0);
        out.insert(pid, Proc { name: stat[a + 1..b].to_string(), ticks: n(11) + n(12), rss_kb: n(21) * page_kb });
    }
    out
}

// (occupé, total) en ticks depuis le démarrage; « id » seul compte comme repos (comme top)
fn cpu_times() -> (u64, u64) {
    let s = fs::read_to_string("/proc/stat").unwrap_or_default();
    let v: Vec<u64> = s.lines().next().unwrap_or("").split_whitespace().skip(1).filter_map(|x| x.parse().ok()).collect();
    let total: u64 = v.iter().take(8).sum();
    (total - v.get(3).copied().unwrap_or(0), total)
}

// Pango et JSON: on retire ce qui casserait l'un ou l'autre, comme l'ancien script
fn clean(s: &str) -> String {
    s.chars().filter(|c| !matches!(c, '&' | '<' | '>' | '"' | '\\')).take(22).collect()
}

fn emit(line: String) {
    let mut out = std::io::stdout().lock();
    if writeln!(out, "{line}").and_then(|_| out.flush()).is_err() {
        process::exit(0);
    }
}

fn cpu(every: Duration, page_kb: u64, hz: f64) {
    let mut prev = procs(page_kb);
    let mut prev_cpu = cpu_times();
    let mut prev_t = Instant::now();
    let mut wait = Duration::from_millis(500); // premier affichage rapide
    loop {
        thread::sleep(wait);
        wait = every;
        let now = procs(page_kb);
        let cur_cpu = cpu_times();
        let secs = prev_t.elapsed().as_secs_f64();
        prev_t = Instant::now();
        let (busy, total) = (cur_cpu.0 - prev_cpu.0, cur_cpu.1 - prev_cpu.1);
        let usage = if total > 0 { busy * 100 / total } else { 0 };
        let mut top: Vec<(f64, &Proc)> = now
            .iter()
            .map(|(pid, p)| {
                let d = p.ticks.saturating_sub(prev.get(pid).filter(|q| q.name == p.name).map_or(p.ticks, |q| q.ticks));
                (d as f64 / hz / secs * 100.0, p)
            })
            .collect();
        top.sort_by(|a, b| b.0.total_cmp(&a.0));
        let tip: Vec<String> = top
            .iter()
            .take(5)
            .map(|(pct, p)| {
                let mem = if p.rss_kb >= 1_048_576 { format!("{:.1}G", p.rss_kb as f64 / 1_048_576.0) } else { format!("{}M", p.rss_kb / 1024) };
                format!("{:<22} {pct:5.1}%  {mem}", clean(&p.name))
            })
            .collect();
        emit(format!(r#"{{"text":" {usage}%","tooltip":"<tt>Top CPU\n{}</tt>"}}"#, tip.join("\\n")));
        prev = now;
        prev_cpu = cur_cpu;
    }
}

fn mem(every: Duration, page_kb: u64) {
    loop {
        let info = fs::read_to_string("/proc/meminfo").unwrap_or_default();
        let field = |k: &str| {
            info.lines().find(|l| l.starts_with(k)).and_then(|l| l.split_whitespace().nth(1)).and_then(|v| v.parse::<u64>().ok()).unwrap_or(0)
        };
        let used = field("MemTotal:").saturating_sub(field("MemAvailable:")) as f64 / 1_048_576.0;
        // RSS cumulé par nom de processus
        let mut by_name: HashMap<String, u64> = HashMap::new();
        for p in procs(page_kb).into_values() {
            *by_name.entry(p.name).or_default() += p.rss_kb;
        }
        let mut top: Vec<(String, u64)> = by_name.into_iter().collect();
        top.sort_by(|a, b| b.1.cmp(&a.1));
        let tip: Vec<String> = top
            .iter()
            .take(5)
            .map(|(n, kb)| {
                let v = if *kb >= 1_048_576 { format!("{:.1} Go", *kb as f64 / 1_048_576.0) } else { format!("{} Mo", kb / 1024) };
                format!("{:<22} {v}", clean(n))
            })
            .collect();
        emit(format!(r#"{{"text":" {used:.1}G","tooltip":"<tt>Top RAM\n{}</tt>"}}"#, tip.join("\\n")));
        thread::sleep(every);
    }
}

// Première sonde disponible: hwmon*/temp1_input puis thermal_zone*/temp (ordre du glob shell); rien dans une VM
fn temp_path() -> Option<String> {
    for (dir, prefix, file) in [("/sys/class/hwmon", "hwmon", "temp1_input"), ("/sys/class/thermal", "thermal_zone", "temp")] {
        let mut names: Vec<String> = fs::read_dir(dir)
            .into_iter()
            .flatten()
            .flatten()
            .filter_map(|e| e.file_name().into_string().ok())
            .filter(|n| n.starts_with(prefix))
            .collect();
        names.sort();
        if let Some(p) = names.iter().map(|n| format!("{dir}/{n}/{file}")).find(|p| fs::metadata(p).is_ok()) {
            return Some(p);
        }
    }
    None
}

fn temp(every: Duration) {
    let path = temp_path();
    loop {
        match path.as_ref().and_then(|p| fs::read_to_string(p).ok()).and_then(|s| s.trim().parse::<i64>().ok()) {
            Some(t) => {
                let c = t / 1000;
                let class = if c >= 80 { "critical" } else { "" };
                emit(format!(r#"{{"text":" {c}°","class":"{class}","tooltip":"Température CPU: {c}°C"}}"#));
            }
            None => emit(r#"{"text":""}"#.into()),
        }
        thread::sleep(every);
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let secs = |default: u64| Duration::from_secs(args.get(2).and_then(|s| s.parse().ok()).unwrap_or(default));
    // SAFETY: sysconf n'a pas d'effet de bord
    let (page_kb, hz) = unsafe { (libc::sysconf(libc::_SC_PAGESIZE) as u64 / 1024, libc::sysconf(libc::_SC_CLK_TCK) as f64) };
    match args.get(1).map(String::as_str) {
        Some("cpu") => cpu(secs(10), page_kb, hz),
        Some("mem") => mem(secs(15), page_kb),
        Some("temp") => temp(secs(15)),
        _ => {
            eprintln!("usage: bar-stats cpu|mem|temp [intervalle en s]");
            process::exit(2);
        }
    }
}
