import std;
import core.stdc.stdlib;

/*
                                ASS - A Simple Shell
    The simplest shell. It does everything that every other shell does, but simpler
    Written by: Mosca
    Date: 6/10/2025
    License: MIT
*/

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

            foreach (_; 0 .. count) runLines(loopBody);
            continue;
        }

        // --- If ... then ... else ---
        if (cmd == "if") {
            string rest = input[2 .. $].strip;
            auto thenSplit = rest.split("then");
            if (thenSplit.length < 2) { writeln("Invalid if statement: ", input); continue; }

            string condition = thenSplit[0].strip;
            string thenElse = thenSplit[1].strip;

            string thenPart;
            string elsePart;
            if (thenElse.canFind("else")) {
                auto parts = thenElse.split("else");
                thenPart = parts[0].strip;
                elsePart = parts[1].strip;
            } else {
                thenPart = thenElse;
                elsePart = "";
            }

            if (evalCondition(condition)) {
                if (!thenPart.empty) runLines([thenPart]);
            } else {
                if (!elsePart.empty) runLines([elsePart]);
            }
            continue;
        }

        // --- Normal commands ---
        string expandedLine = expandVariables(input);
        auto lineTokens = expandedLine.split();
        if (lineTokens.length == 0) continue;

        string lineCmd = lineTokens[0];
        string[] lineArgs = lineTokens[1 .. $];

        if (lineCmd.startsWith("$") && lineArgs.length >= 2 && lineArgs[0] == "=") {
            handleAssignment(expandedLine);
            continue;
        }

        switch (lineCmd) {
            case "print": if (lineArgs.length > 0) writeln(lineArgs.join(" ")); break;
            case "cnf": if (lineArgs.length > 0) { try { auto f = File(lineArgs.join(" "), "w"); f.close(); } catch (Exception e) { writeln(e.msg); } } break;
            case "butt": if (lineArgs.length > 0) runButtScript(lineArgs.join(" ")); break;
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
            case "etf":
                if (lineArgs.length > 0) {
                    try { auto result = execute([lineArgs[0]] ~ lineArgs[1 .. $]); writeln("Exit code: ", result.status); }
                    catch (Exception e) { writeln("Failed to run: ", e.msg); }
                }
                break;
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
                if(args.length > 0){
                    try { auto result = execute([args[0]] ~ args[1 .. $]); writeln("Exit code: ", result.status); }
                    catch(Exception e){ writeln("Failed to run: ", e.msg); }
                }
                break;
            case "butt": if(args.length > 0) runButtScript(args.join(" ")); break;
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
butt [butname] - run a .but file
qtp - quit the program
help - displays this message
                };
                writeln(help);
                break;
            default: writeln("Unknown command: ", cmd);
        }
    }
}

