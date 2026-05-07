function [installed, errMsg] = installOnStaticClasspath(classpathFile, jarPath)
%INSTALLONSTATICCLASSPATH Add a JAR to MATLAB's static Java classpath file.
%   [INSTALLED, ERRMSG] = INSTALLONSTATICCLASSPATH(CLASSPATHFILE, JARPATH)
%   ensures that JARPATH (a canonical absolute path to a JAR) appears
%   on its own line in CLASSPATHFILE, and that no other
%   `snakeyaml-*.jar` lines remain. If a change is needed, the file is
%   rewritten atomically via a temporary file. If CLASSPATHFILE does
%   not exist, it is created.
%
%   The static Java classpath file is read by MATLAB at JVM startup;
%   on Windows it lives at `<prefdir>/javaclasspath.txt`, which is
%   under the current user's `%APPDATA%` and writable without admin.
%   Changes take effect on the *next* MATLAB session.
%
%   Inputs:
%     CLASSPATHFILE (1, 1) string - target classpath file (typically
%                                   fullfile(prefdir, 'javaclasspath.txt'))
%     JARPATH       (1, 1) string - canonical absolute path of the JAR
%
%   Outputs:
%     INSTALLED (1, 1) logical - true if the file was created or
%                                modified, false if it was already up
%                                to date or the write failed
%     ERRMSG    (1, 1) string  - empty on success or no-op; populated
%                                with a short reason on failure (e.g.
%                                directory missing, permission denied)

    arguments
        classpathFile (1, 1) string
        jarPath (1, 1) string
    end

    installed = false;
    errMsg = "";

    targetDir = fileparts(classpathFile);
    if strlength(string(targetDir)) > 0 && ~isfolder(targetDir)
        errMsg = sprintf("Target directory does not exist: %s", targetDir);
        return;
    end

    existing = readClasspathLines(classpathFile);
    [desired, changed] = reconcileSnakeYamlClasspath(existing, jarPath);

    if ~changed
        return;
    end

    try
        atomicWriteLines(classpathFile, desired);
        installed = true;
    catch ME
        errMsg = string(ME.message);
    end
end

function lines = readClasspathLines(filePath)
%READCLASSPATHLINES Return file contents as a column string array of lines.
%   Returns an empty 0-by-1 string if the file does not exist. Strips a
%   single trailing empty element introduced by a trailing newline.
%
%   Inputs:
%     FILEPATH (1, 1) string
%   Outputs:
%     LINES (:, 1) string
    arguments
        filePath (1, 1) string
    end

    if ~isfile(filePath)
        lines = string.empty(0, 1);
        return;
    end

    raw = string(fileread(filePath));
    lines = splitlines(raw);
    if ~isempty(lines) && lines(end) == ""
        lines(end) = [];
    end
    lines = lines(:);  % ensure column shape
end

function atomicWriteLines(targetFile, lines)
%ATOMICWRITELINES Write LINES to TARGETFILE atomically (tmp + rename).
%   Writes to `<targetFile>.tmp`, then moves over `targetFile` with
%   force-overwrite. On Windows this uses MoveFileEx semantics under
%   the hood (close-to-atomic; sufficient for a per-user preferences
%   file). Throws on any failure.
%
%   Inputs:
%     TARGETFILE (1, 1) string
%     LINES      (:, 1) string
    arguments
        targetFile (1, 1) string
        lines (:, 1) string
    end

    tmp = targetFile + ".tmp";
    fid = fopen(char(tmp), "w");
    if fid < 0
        error("yaml:initialization:CannotOpenTmp", ...
            "Cannot open %s for writing.", tmp);
    end
    try
        if ~isempty(lines)
            fprintf(fid, "%s\n", lines);
        end
        fclose(fid);
    catch ME
        try
            fclose(fid);
        catch
        end
        try
            delete(char(tmp));
        catch
        end
        rethrow(ME);
    end

    movefile(char(tmp), char(targetFile), 'f');
end
