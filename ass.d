import std;
import core.stdc.stdlib;


/*
                                ASS - A Simple Shell
    The simplest shell. It does everything that every other shell does, but simpler
    Written by: Mosca
    Date: 6/10/2025
    License: MIT
*/


import std.stdio;
import std.process;
import std.string;
import std.file;
import std.conv;
import core.stdc.stdlib : malloc, free, exit;
import core.stdc.string : strerror;
import core.stdc.errno : errno;

version (Posix) {
    import core.sys.posix.unistd : fork, execvp, pid_t;
    import core.sys.posix.sys.wait : waitpid, WEXITSTATUS;
}

// Helper function to run a process on Posix
version (Posix)
void runPosixProcess(string[] args) {
    if (args.length == 0) {
        writeln("ETF: missing program name");
        return;
    }

    const(char)* program = toStringz(args[0]);
    const(char)** argv = cast(const(char)**)malloc((args.length + 1) * (void*).sizeof);
    foreach (i, arg; args)
        argv[i] = toStringz(arg);
    argv[args.length] = null;

    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        execvp(program, argv);
        // If execvp returns, it failed
        stderr.writeln("ASS: failed to execute ", args[0], ": ", strerror(errno));
        exit(1);
    } else if (pid > 0) {
        // Parent process
        int status;
        waitpid(pid, &status, 0);
        writeln("Program exited with code ", WEXITSTATUS(status));
    } else {
        stderr.writeln("ASS: fork() failed!");
    }

    free(argv);
}

// Windows version using spawnProcess
version (Windows)
void runWindowsProcess(string[] args) {
    if (args.length == 0) {
        writeln("ETF: missing program name");
        return;
    }

    try {
        auto p = spawnProcess(args);
        auto exitCode = wait(p);
        writeln("Program exited with code ", exitCode);
    } catch (Exception e) {
        writeln("ETF error: ", e.msg);
    }
}

// --- Rudimentary line-based text editor ---
void runEditor(string filename) {
    if (filename.empty) {
        writeln("Usage: edit <filename>");
        return;
    }

    string[] lines;
    bool dirty = false;

    if (exists(filename)) {
        try {
            lines = readText(filename).splitLines();
        } catch (Exception e) {
            writeln("Failed to open file: ", e.msg);
            return;
        }
    } else {
        lines = [];
    }

    writeln("Simple editor for: ", filename);
    writeln("Commands: p=print, i N=insert after N, a=append, d N=delete, r N=replace, w=write, q=quit, h=help");

    while (true) {
        write("ed> ");
        string cmd = readln().strip;
        if (cmd.empty) continue;

        auto parts = cmd.split();
        string op = parts[0];

        if (op == "p") {
            foreach (i, l; lines) {
                writeln(i + 1, ": ", l);
            }
            continue;
        }

        if (op == "h" || op == "?") {
            writeln("Commands:");
            writeln("  p           - print file with line numbers");
            writeln("  i N         - insert lines after line N (end with a single '.')");
            writeln("  a           - append lines to end (end with a single '.')");
            writeln("  d N         - delete line N");
            writeln("  r N         - replace line N with a single line");
            writeln("  w           - write/save to disk");
            writeln("  q           - quit (prompts if unsaved)");
            continue;
        }

        if (op == "i") {
            if (parts.length < 2) { writeln("Usage: i N"); continue; }
            int n;
            try { n = to!int(parts[1]); } catch (Exception) { writeln("Invalid line number"); continue; }

            // collect lines until a single '.'
            string[] newLines;
            writeln("Enter lines, single '.' on a line to finish:");
            while (true) {
                string ln = readln();
                if (ln.strip == ".") break;
                newLines ~= ln.strip;
            }

            size_t pos = (n <= 0) ? 0 : cast(size_t) n;
            if (pos > lines.length) pos = lines.length;
            // insert after line n => index pos
            lines = lines[0 .. pos] ~ newLines ~ lines[pos .. $];
            dirty = true;
            continue;
        }

        if (op == "a") {
            string[] newLines;
            writeln("Enter lines, single '.' on a line to finish:");
            while (true) {
                string ln = readln();
                if (ln.strip == ".") break;
                newLines ~= ln.strip;
            }
            lines ~= newLines;
            dirty = true;
            continue;
        }

        if (op == "d") {
            if (parts.length < 2) { writeln("Usage: d N"); continue; }
            int n;
            try { n = to!int(parts[1]); } catch (Exception) { writeln("Invalid line number"); continue; }
            if (n <= 0 || cast(size_t) n > lines.length) { writeln("Line out of range"); continue; }
            lines = lines[0 .. n - 1] ~ lines[n .. $];
            dirty = true;
            continue;
        }

        if (op == "r") {
            if (parts.length < 2) { writeln("Usage: r N"); continue; }
            int n;
            try { n = to!int(parts[1]); } catch (Exception) { writeln("Invalid line number"); continue; }
            if (n <= 0 || cast(size_t) n > lines.length) { writeln("Line out of range"); continue; }
            write("New content: ");
            string content = readln().strip;
            lines[n - 1] = content;
            dirty = true;
            continue;
        }

        if (op == "w") {
            try {
                // Use File to write since writeText may not be available in all std versions
                auto f = File(filename, "w");
                f.write(lines.join("\n"));
                f.close();
                writeln("Saved ", filename);
                dirty = false;
            } catch (Exception e) {
                writeln("Failed to write file: ", e.msg);
            }
            continue;
        }

        if (op == "q") {
            if (dirty) {
                write("Unsaved changes, quit without saving? (y/N): ");
                string ans = readln().strip.toLower();
                if (ans != "y") continue;
            }
            writeln("Exiting editor.");
            break;
        }

        writeln("Unknown editor command. Type 'h' for help.");
    }
}

// --- Call this from your command handling ---
void ETF(string[] args) {
    version (Posix) {
        runPosixProcess(args);
    } else version (Windows) {
        runWindowsProcess(args);
    }
}



string[] tokenize(string input) {
    string[] tokens;
    bool inQuotes = false;
    string current;

    foreach(c; input) {
        if (c == '"') {
            inQuotes = !inQuotes;
        } else if (c == ' ' && !inQuotes) {
            if (!current.empty) {
                tokens ~= current;
                current = "";
            }
        } else {
            current ~= c;
        }
    }
    if (!current.empty)
        tokens ~= current;

    return tokens;
}

string[string] vars;

// --- Expression evaluator ---
double evalExpression(string expr) {
    foreach (k, v; vars)
        expr = expr.replace("$" ~ k, v);

    expr = expr.strip.replace(" ", "");

    string[] tokens;
    string num;
    foreach (ch; expr) {
        if (ch.isDigit || ch == '.') {
            num ~= ch;
        } else if (ch == '+' || ch == '-' || ch == '*' || ch == '/' || ch == '%') {
            if (!num.empty) {
                tokens ~= num;
                num = "";
            }
            tokens ~= ch ~ "";
        }
    }
    if (!num.empty) tokens ~= num;

    if (tokens.length == 0) return 0;
    double result = to!double(tokens[0]);
    size_t i = 1;
    while (i + 1 < tokens.length) {
        string op = tokens[i];
        double val = to!double(tokens[i + 1]);
        switch (op) {
            case "+": result += val; break;
            case "-": result -= val; break;
            case "*": result *= val; break;
            case "/": if (val != 0) result /= val; break;
            case "%": result = cast(int)result % cast(int)val; break;
            default: break;
        }
        i += 2;
    }
    return result;
}

// --- Expand variables ---
string expandVariables(string s) {
    foreach (k, v; vars)
        s = s.replace("$" ~ k, v);
    return s;
}

// --- Handle variable assignment ---
void handleAssignment(string line) {
    auto parts = line.split("=");
    if (parts.length >= 2) {
        string name = parts[0][1 .. $].strip;
        string value = parts[1 .. $].join("=").strip;

        // Special input handling
        if (value == "@") {
            vars[name] = readln().strip;
            return;
        }

        double val;
        bool numeric = true;
        try {
            val = evalExpression(value);
        } catch (Exception) {
            numeric = false;
        }

        vars[name] = numeric ? to!string(val) : expandVariables(value);
    } else {
        writeln("Invalid variable assignment: ", line);
    }
}

// --- Evaluate conditions for if statements ---
bool evalCondition(string cond) {
    cond = expandVariables(cond);

    string[] operators = ["==", "!=", "<=", ">=", "<", ">"];
    foreach (op; operators) {
        if (cond.canFind(op)) {
            auto parts = cond.split(op);
            if (parts.length != 2) return false;
            double left = evalExpression(parts[0].strip);
            double right = evalExpression(parts[1].strip);
            final switch (op) {
                case "==": return left == right;
                case "!=": return left != right;
                case "<": return left < right;
                case ">": return left > right;
                case "<=": return left <= right;
                case ">=": return left >= right;
            }
        }
    }

    // Handle single modulo expressions like "$x % 2 == 0"
    if (cond.canFind("%")) {
        auto parts = cond.split("%");
        if (parts.length != 2) return false;
        int left = cast(int) evalExpression(parts[0].strip);
        int right = cast(int) evalExpression(parts[1].strip);
        return left % right == 0;
    }

    // Fallback: non-zero numeric is true
    double val = evalExpression(cond);
    return val != 0;
}

// --- Execute script lines recursively ---
void runLines(string[] lines, size_t start = 0, size_t end = size_t.max) {
    if (end == size_t.max) end = lines.length;
    size_t i = start;

    while (i < end) {
        string input = lines[i].strip;
        i++;

        if (input.empty || input.startsWith("#")) continue;

        // Skip standalone block control keywords
        if (input == "end" || input == "else") continue;

        // --- Variable assignment ---
        if (input.startsWith("$")) {
            handleAssignment(input);
            continue;
        }

        auto tokens = input.split();
        if (tokens.length == 0) continue;

        string cmd = tokens[0];
        string[] args = tokens[1 .. $];

        // --- Loops ---
        if (cmd == "loop" && args.length >= 2 && args[$-1] == "do") {
            string countStr = expandVariables(args[0]);
            int count;
            try count = to!int(countStr);
            catch (Exception) { writeln("Invalid loop count: ", countStr); continue; }

            string[] loopBody;
            int nested = 1;
            while (i < end) {
                string inner = lines[i].strip;
                i++;
                if (inner.startsWith("loop") && inner.endsWith("do")) nested++;
                if (inner == "end") {
                    nested--;
                    if (nested == 0) break;
                }
                loopBody ~= inner;
            }

            if (count == -1) {
                while (true) runLines(loopBody);
            } else {
                foreach (_; 0 .. count) runLines(loopBody);
            }

            continue;
        }

        // --- Multiline IF ---
        if (cmd == "if") {
            if (!input.endsWith("then")) {
                writeln("Syntax error: 'if' must end with 'then' and use multiline blocks.");
                continue;
            }

            string condition = input[2 .. $].replace("then", "").strip;
            string[] thenBody;
            string[] elseBody;
            bool inElse = false;
            int nested = 1;

            while (i < end) {
                string inner = lines[i].strip;
                i++;

                if (inner.startsWith("if") && inner.endsWith("then")) {
                    nested++;
                } else if (inner == "end") {
                    nested--;
                    if (nested == 0) break;
                    continue; // skip nested ends
                } else if (inner == "else" && nested == 1) {
                    inElse = true;
                    continue; // skip the else line
                }

                if (inElse)
                    elseBody ~= inner;
                else
                    thenBody ~= inner;
            }

            if (evalCondition(condition))
                runLines(thenBody);
            else
                runLines(elseBody);

            continue;
        }

        // --- Normal commands ---
        string expandedLine = expandVariables(input);
        auto lineTokens = expandedLine.split();
        if (lineTokens.length == 0) continue;

        string lineCmd = lineTokens[0];
        string[] lineArgs = lineTokens[1 .. $];

        // Assignment shortcut
        if (lineCmd.startsWith("$") && lineArgs.length >= 2 && lineArgs[0] == "=") {
            handleAssignment(expandedLine);
            continue;
        }

        // Commands switch...
        switch (lineCmd) {
            case "print": if (lineArgs.length > 0) writeln(lineArgs.join(" ")); break;
            case "cnf": if (lineArgs.length > 0) { try { auto f = File(lineArgs.join(" "), "w"); f.close(); } catch (Exception e) { writeln(e.msg); } } break;
            case "butt": if (lineArgs.length > 0) runButtScript(lineArgs.join(" ")); break;
            case "timi": if (lineArgs.length > 0) runTimiScript(lineArgs.join(" ")); else runTimiScript(); break;
            case "edit": if (lineArgs.length > 0) runEditor(lineArgs.join(" ")); else runEditor("untitled.txt"); break;
            case "pfc": if (lineArgs.length > 0) printFileContents(lineArgs.join(" ")); else writeln("Usage: pfc <filename>"); break;
            case "pcdc":
                foreach (entry; dirEntries(".", SpanMode.shallow))
                    writeln(entry.isDir ? "[DIR] " ~ entry.name : "[FILE] " ~ entry.name);
                break;
            case "pcd": writeln(getcwd()); break;
            case "jtd": if (lineArgs.length > 0) { try { chdir(lineArgs.join(" ")); } catch (Exception e) { writeln(e.msg); } } break;
            case "jtpd": chdir(".."); break;
            case "rsf": if (lineArgs.length > 0) { try { remove(lineArgs.join(" ")); } catch (Exception e) { writeln(e.msg); } } break;
            case "rsd": if (lineArgs.length > 0) { try { rmdirRecurse(lineArgs.join(" ")); } catch (Exception e) { writeln(e.msg); } } break;
            case "cnd": if (lineArgs.length > 0) { try { mkdir(lineArgs.join(" ")); } catch (Exception e) { writeln(e.msg); } } break;
            case "csc": version(Windows) system("cls"); else system("clear"); break;
            case "etf": ETF(lineArgs); break;
            case "qtp": break;
            case "help": writeln("Help..."); break;
            default: writeln("Unknown command: ", lineCmd);
        }
    }

}

// --- Run .butt script ---
void runButtScript(string filename) {
    if (!exists(filename)) {
        writeln("File not found: ", filename);
        return;
    }
    if(filename.canFind(".butt")){
        auto lines = readText(filename).splitLines();
        runLines(lines);
    } else {
        writeln("Error: Invalid file type, please make sure you're using a butt file");
    }
}



void main() {
    writeln("ASS - A Simple Shell");
    writeln("The simplest shell. It does everything that every other shell does, but simpler");
    writeln("Version 1.0 - written by Mosca");

    while(true) {
        write("=> ");
        string input = readln().strip;
        if (input.empty) continue;

        auto tokens = tokenize(input);
        if (tokens.length == 0) continue;

        string cmd = tokens[0];
        string[] args = tokens[1 .. $];

        switch(cmd) {
            case "qtp": return;
            case "pcdc":
                foreach(entry; dirEntries(".", SpanMode.shallow))
                    writeln(entry.isDir ? "[DIR] " ~ entry.name : "[FILE] " ~ entry.name);
                break;
            case "pcd": writeln(getcwd()); break;
            case "jtd": if(args.length > 0) { try { chdir(args.join(" ")); } catch(Exception e){ writeln(e.msg); } } break;
            case "jtpd": chdir(".."); break;
            case "rsf": if(args.length > 0){ try{ remove(args.join(" ")); } catch(Exception e){ writeln(e.msg); } } break;
            case "rsd": if(args.length > 0){ try{ rmdirRecurse(args.join(" ")); } catch(Exception e){ writeln(e.msg); } } break;
            case "cnf": if(args.length > 0){ try{ auto f = File(args.join(" "), "w"); f.close(); } catch(Exception e){ writeln(e.msg); } } break;
            case "cnd": if(args.length > 0){ try{ mkdir(args.join(" ")); } catch(Exception e){ writeln(e.msg); } } break;
            case "csc": version(Windows) system("cls"); else system("clear"); break;
            case "etf":
                ETF(args);
                break;
            case "butt": if(args.length > 0) runButtScript(args.join(" ")); break;
            case "timi": if(args.length > 0) runTimiScript(args.join(" ")); else runTimiScript(); break;
            case "edit": if(args.length > 0) runEditor(args.join(" ")); else runEditor("untitled.txt"); break;
            case "pfc": if(args.length > 0) printFileContents(args.join(" ")); else writeln("Usage: pfc <filename>"); break;
            case "help":
                string help = q{
pcdc - print current directory content
pcd - print current directory
jtd [dir] - jump to directory [dir]
jtpd - jump to previous directory (you can also do "jtd ..")
rsf [file] - remove specified file [file]
rsd [dir] - remove specified directory [dir]
cnf [filename] - create new file
cnd [dirname] - create new directory
csc - clear screen content
etf [exename] - execute the file [exename]
butt [butname] - run a .butt file
qtp - quit the program
help - displays this message
                };
                writeln(help);
                break;
            default: writeln("Unknown command: ", cmd);
        }
    }
}


// --- Run timi.py (or another python script) ---
version (EmbedPython) {
    import std.string : toStringz;
    import std.file : readText;
    extern(C) void Py_Initialize();
    extern(C) int PyRun_SimpleString(const(char)*);
    extern(C) int Py_FinalizeEx();

    // Execute local timi.py inside the current process using Python C API.
    // Compile with: dmd -version=EmbedPython ass.d -L<python-lib>
    void runTimiScript(string filename = "timi.py") {
        string timiPath = filename;
        if (timiPath.empty) timiPath = "timi.py";

        // For embedding, require a local timi.py
        if (!exists(timiPath)) {
            writeln("Embed mode requires a local 'timi.py' in the current directory.");
            return;
        }

        string code;
        try {
            code = readText(timiPath);
        } catch (Exception e) {
            writeln("Failed to read ", timiPath, ": ", e.msg);
            return;
        }

        // Prepare bootstrap: set sys.argv and execute the code
        string argList = "['timi'";
        // if filename refers to a .tim passed as arg to timi, include it
        if (timiPath.canFind(".tim") || !filename.empty && filename != "timi.py") {
            // Sanitize backslashes/quotes for embedding
            string safe = filename.replace("\\", "\\\\").replace("\"", "\\\"");
            argList ~= ", \"" ~ safe ~ "\"";
        }
        argList ~= "]";

        string pyCode = "import sys\n" ~ "sys.argv = " ~ argList ~ "\n" ~ code;

        Py_Initialize();
        int rc = PyRun_SimpleString(toStringz(pyCode));
        int frc = Py_FinalizeEx();
        if (rc != 0) writeln("timi (embedded) returned code ", rc);
        if (frc != 0) writeln("Py_FinalizeEx returned ", frc);
    }
} else {
    // Fallback: prefer local timi.py when present, otherwise run the target directly
    void runTimiScript(string filename = "timi.py") {
        if (filename.empty) filename = "timi.py";

        // If the target is a .tim file and local timi.py exists, run timi.py with that file
        if (filename.canFind(".tim") && exists("timi.py")) {
            string[][] candidates = [["python", "timi.py", filename], ["python3", "timi.py", filename]];
            foreach (cand; candidates) {
                try {
                    ETF(cand);
                    return;
                } catch (Exception e) {
                    // try next
                }
            }
            writeln("Failed to run timi.py with Python. Make sure Python is installed.");
            return;
        }

        // Otherwise try running the filename directly with python
        string[][] candidates = [["python", filename], ["python3", filename]];
        foreach (cand; candidates) {
            try {
                ETF(cand);
                return;
            } catch (Exception e) {
                // try next
            }
        }

        writeln("Failed to run ", filename, ". Make sure Python is installed and available as 'python' or 'python3'.");
    }
}

// Print file contents with line numbers
void printFileContents(string filename) {
    if (filename.empty) {
        writeln("Usage: pfc <filename>");
        return;
    }

    if (!exists(filename)) {
        writeln("File not found: ", filename);
        return;
    }

    string[] lines;
    try {
        lines = readText(filename).splitLines();
    } catch (Exception e) {
        writeln("Failed to read file: ", e.msg);
        return;
    }

    foreach (i, l; lines) {
        writeln(i + 1, ": ", l);
    }
}
