function tf = isJarOnJavaClasspath(jarPath)
%ISJARONJAVACLASSPATH True if a JAR (canonical absolute path) is on MATLAB's Java classpath.
%   TF = ISJARONJAVACLASSPATH(JARPATH) returns true iff JARPATH appears
%   on the static or dynamic Java classpath as reported by
%   `javaclasspath`. Comparison is in canonical form so that case,
%   forward/back slash, and trailing-separator differences do not
%   produce false negatives.
%
%   Used to decide whether JAVAADDPATH must be called for the current
%   session. After a MATLAB restart that picked up a new
%   `javaclasspath.txt` entry, the JAR is on the static classpath -
%   calling JAVAADDPATH again would emit a "already specified" warning
%   (the static classpath is read by MATLAB's main classloader, which
%   `java.lang.Class.forName` from MATLAB does not always traverse;
%   that is why we cannot use a class-resolution probe here).
%
%   Inputs:
%     JARPATH (1, 1) string - canonical absolute path of a JAR
%   Outputs:
%     TF (1, 1) logical

    arguments
        jarPath (1, 1) string  % canonical absolute path
    end

    entries = string([javaclasspath('-static'); javaclasspath('-dynamic')]);
    for i = 1:numel(entries)
        if canonicalJavaPath(entries(i)) == jarPath
            tf = true;
            return;
        end
    end
    tf = false;
end
