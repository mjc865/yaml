function initializeSnakeYaml
%INITIALIZESNAKEYAML Ensure the bundled SnakeYAML JAR is on the Java classpath.
%   On the first call in a MATLAB session this function:
%
%     1. Adds the JAR's absolute path to the user's static Java
%        classpath file (`<prefdir>/javaclasspath.txt`) if it is not
%        already there. This file lives under the current user's
%        AppData and requires no admin rights.
%        Stale `snakeyaml-*.jar` entries pointing to other locations
%        (left over from a previous install) are removed at the same
%        time. The file is rewritten atomically.
%     2. For the *current* session, falls back to JAVAADDPATH so the
%        JAR is usable immediately. This carries the well-known 20-30s
%        first-run cost on Windows (dynamic-classpath reload + AV scan
%        + lazy SnakeYAML class loading + JIT). The static-classpath
%        change written in step 1 takes effect on the *next* MATLAB
%        session, eliminating that cost from then on.
%     3. Caches a persistent flag so subsequent calls in the same
%        session are a no-op.
%
%   Net effect on a deployment target: the slow first-run cost is paid
%   exactly once per machine. All later MATLAB sessions start fast.
%
%   The warning 'yaml:initialization:RestartForFasterStartup' is
%   emitted on the install. Silence it with:
%       warning('off', 'yaml:initialization:RestartForFasterStartup');
%
%   No input or output arguments.
%
%   See also YAML.LOAD, JAVACLASSPATH, JAVAADDPATH, PREFDIR.

    persistent isInitialized
    if ~isempty(isInitialized) && isInitialized
        return;
    end

    % Resolve canonical absolute path of the bundled JAR. Canonical form
    % avoids spurious mismatches between e.g. C:\... and c:\..\..\..\..
    jarPath = canonicalJavaPath(string(fullfile( ...
        fileparts(mfilename('fullpath')), '..', 'snakeyaml', ...
        'snakeyaml-1.30.jar')));

    % Try to update <prefdir>/javaclasspath.txt for future sessions.
    classpathFile = string(fullfile(prefdir, 'javaclasspath.txt'));
    [installed, installError] = installOnStaticClasspath(classpathFile, jarPath);

    % For THIS session, ensure the JAR is loadable. Skip javaaddpath
    % if the JAR is already on the static or dynamic classpath. After
    % a restart that picked up our javaclasspath.txt entry, the JAR is
    % already on the static classpath and another javaaddpath would
    % emit a "already specified on java path" warning. On the very
    % first session post-install, the static entry has not been read
    % yet, so the dynamic add is the slow path that loads the classes.
    if ~isJarOnJavaClasspath(jarPath)
        javaaddpath(char(jarPath));
    end

    if installed
        warning('yaml:initialization:RestartForFasterStartup', ...
            ['SnakeYAML was added to the static Java classpath ' ...
             '(%s). Restart MATLAB to skip the dynamic-load delay ' ...
             'on future sessions.'], char(classpathFile));
    elseif strlength(installError) > 0
        warning('yaml:initialization:StaticClasspathUnavailable', ...
            ['Could not update static Java classpath (%s): %s. ' ...
             'Each MATLAB session will repeat the first-call delay.'], ...
            char(classpathFile), char(installError));
    end

    isInitialized = true;
end
