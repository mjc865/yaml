function [out, changed] = reconcileSnakeYamlClasspath(in, jarPath)
%RECONCILESNAKEYAMLCLASSPATH Compute updated classpath-file lines.
%   [OUT, CHANGED] = RECONCILESNAKEYAMLCLASSPATH(IN, JARPATH) takes the
%   current contents of `javaclasspath.txt` (one line per element) and
%   returns the desired contents OUT and a flag CHANGED indicating
%   whether OUT differs from IN (i.e. whether the file needs to be
%   rewritten).
%
%   Behavior:
%     - Comments (lines starting with `#`) and blank lines are
%       preserved.
%     - Existing lines whose path is a `snakeyaml-*.jar` reference are
%       compared (canonical form) to JARPATH:
%         * exact match -> kept; no append needed.
%         * different path -> removed (treated as a stale leftover from
%           a prior install location).
%     - If no exact match was found, JARPATH (already canonical) is
%       appended as a new last line.
%     - The optional MATLAB classpath markers `<before>` / `<after>`
%       at the start of a line are recognized and stripped only for
%       the purpose of comparison. Stale entries that carry such a
%       marker are also removed.
%
%   This function is pure: no filesystem or JVM access. It is unit-
%   testable in isolation. The wrapper INSTALLONSTATICCLASSPATH calls
%   it after reading the file and writes the result if CHANGED is true.
%
%   Inputs:
%     IN      (:, 1) string - existing lines from `javaclasspath.txt`
%                             (no trailing newline element)
%     JARPATH (1, 1) string - canonical absolute path of the snakeyaml
%                             JAR to install
%
%   Outputs:
%     OUT     (:, 1) string - desired lines after reconciliation
%     CHANGED (1, 1) logical - true if OUT differs from IN

    arguments
        in (:, 1) string
        jarPath (1, 1) string
    end

    keepMask = true(size(in));
    alreadyHasExact = false;

    for i = 1:numel(in)
        rawLine = in(i);
        trimmed = strtrim(rawLine);

        % Preserve comments and blank lines exactly.
        if trimmed == "" || startsWith(trimmed, "#")
            continue;
        end

        % Strip optional <before>/<after> marker for comparison only.
        pathPart = strtrim(regexprep(trimmed, '^\s*<(?:before|after)>\s*', ''));

        if ~isSnakeYamlJarReference(pathPart)
            continue;
        end

        % Canonical-compare. If the referenced path no longer exists on
        % disk, getCanonicalPath still returns a normalized form, which
        % is sufficient for string equality with our canonical jarPath.
        otherCanon = canonicalJavaPath(pathPart);
        if otherCanon == jarPath
            alreadyHasExact = true;
        else
            keepMask(i) = false;  % stale entry from prior install
        end
    end

    out = in(keepMask);
    changed = any(~keepMask);

    if ~alreadyHasExact
        out(end+1, 1) = jarPath;
        changed = true;
    end
end

function tf = isSnakeYamlJarReference(pathPart)
%ISSNAKEYAMLJARREFERENCE True if PATHPART points at a snakeyaml-*.jar.
%   Heuristic match by filename ('snakeyaml*' base, '.jar' extension),
%   case-insensitive. Used to identify entries we are responsible for
%   maintaining; lines pointing at unrelated JARs are left alone.
%
%   Inputs:
%     PATHPART (1, 1) string - a path-like classpath entry
%   Outputs:
%     TF (1, 1) logical
    arguments
        pathPart (1, 1) string
    end
    [~, name, ext] = fileparts(pathPart);
    tf = lower(string(ext)) == ".jar" && ...
         startsWith(lower(string(name)), "snakeyaml");
end
