function out = canonicalJavaPath(p)
%CANONICALJAVAPATH Return the canonical absolute form of a filesystem path.
%   OUT = CANONICALJAVAPATH(P) resolves '.' and '..' segments, applies
%   the OS canonicalization (case folding on Windows, symlink
%   resolution where possible), and returns the result as a string.
%
%   Used to compare paths from `javaclasspath.txt` against the bundled
%   JAR location reliably across deploys (where short-name vs long-name
%   or different-case drive letters could otherwise create duplicate
%   entries).
%
%   If the path cannot be canonicalized (e.g. an unresolvable parent
%   does not exist), the input is returned unchanged.
%
%   Inputs:
%     P (1, 1) string - filesystem path, absolute or relative
%
%   Outputs:
%     OUT (1, 1) string - canonical form of P

    arguments
        p (1, 1) string  % filesystem path
    end

    try
        out = string(java.io.File(char(p)).getCanonicalPath());
    catch
        out = p;
    end
end
