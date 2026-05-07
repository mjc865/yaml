classdef InitializeTests < matlab.unittest.TestCase
    %INITIALIZETESTS Tests for the self-installing initializeSnakeYaml.
    %   Covers:
    %     - Pure reconciliation logic (no filesystem)
    %     - File-level install on a temp javaclasspath.txt
    %     - End-to-end smoke test (yaml.load still works)

    methods (Test)

        %% reconcileSnakeYamlClasspath - pure logic

        function reconcile_emptyInput_appendsJar(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            [out, changed] = reconcileSnakeYamlClasspath(string.empty(0,1), jar);
            testCase.verifyTrue(changed);
            testCase.verifyEqual(out, jar);
        end

        function reconcile_exactMatch_noChange(testCase)
            % Caller of reconcile is responsible for canonicalizing
            % the JAR path. The on-disk line is canonicalized inside
            % the function. Use a fabricated snakeyaml path so the
            % function recognizes it as a managed entry.
            jar = "C:\pkg\snakeyaml-1.30.jar";
            in = jar;
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyFalse(changed);
            testCase.verifyEqual(out, in);
        end

        function reconcile_staleEntry_removed(testCase)
            jar = "C:\new\snakeyaml-1.30.jar";
            in = "C:\old\snakeyaml-1.30.jar";
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyTrue(changed);
            testCase.verifyEqual(out, jar);
        end

        function reconcile_preservesCommentsAndBlanks(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            in = [
                "# user-managed entries below";
                "";
                "C:\other\some-other.jar";
                "  # indented comment";
                "C:\old\snakeyaml-1.30.jar"];  % stale
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyTrue(changed);
            % Stale snakeyaml line removed; everything else preserved;
            % new jar appended.
            testCase.verifyEqual(out, [
                "# user-managed entries below";
                "";
                "C:\other\some-other.jar";
                "  # indented comment";
                jar]);
        end

        function reconcile_unrelatedJarsLeftAlone(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            in = [
                "C:\libs\httpclient.jar";
                "C:\libs\jackson-core.jar"];
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyTrue(changed);  % new line appended
            testCase.verifyEqual(out, [in; jar]);
        end

        function reconcile_multipleStaleEntries_allRemoved(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            in = [
                "D:\v1\snakeyaml-1.29.jar";
                "C:\unrelated\foo.jar";
                "E:\v2\snakeyaml-1.30.jar"];
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyTrue(changed);
            testCase.verifyEqual(out, ["C:\unrelated\foo.jar"; jar]);
        end

        function reconcile_beforeMarkerStripped(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            in = "<before> C:\old\snakeyaml-1.30.jar";  % stale w/ marker
            [out, changed] = reconcileSnakeYamlClasspath(in, jar);
            testCase.verifyTrue(changed);
            testCase.verifyEqual(out, jar);
        end

        function reconcile_idempotentAcrossCalls(testCase)
            jar = "C:\pkg\snakeyaml-1.30.jar";
            [out1, changed1] = reconcileSnakeYamlClasspath(string.empty(0,1), jar);
            testCase.verifyTrue(changed1);
            [out2, changed2] = reconcileSnakeYamlClasspath(out1, jar);
            testCase.verifyFalse(changed2);
            testCase.verifyEqual(out2, out1);
        end

        %% installOnStaticClasspath - file-level integration

        function install_createsMissingFile(testCase)
            tmpDir = createTempDir(testCase);
            classpathFile = string(fullfile(tmpDir, 'javaclasspath.txt'));
            jar = canonicalJavaPath(string(fullfile(tmpDir, "snakeyaml-1.30.jar")));

            [installed, err] = installOnStaticClasspath(classpathFile, jar);

            testCase.verifyTrue(installed);
            testCase.verifyEqual(err, "");
            testCase.verifyTrue(isfile(classpathFile));
            written = readLines(classpathFile);
            testCase.verifyEqual(written, jar);
        end

        function install_alreadyUpToDate_noWrite(testCase)
            tmpDir = createTempDir(testCase);
            classpathFile = string(fullfile(tmpDir, 'javaclasspath.txt'));
            % Must use a snakeyaml-named path: the function only
            % recognizes (and idempotently re-installs) such entries.
            jar = canonicalJavaPath(string(fullfile(tmpDir, "snakeyaml-1.30.jar")));

            % First install creates the file.
            installOnStaticClasspath(classpathFile, jar);
            mtime1 = dir(classpathFile).datenum;

            pause(1.1);  % file timestamps on FAT/NTFS round to seconds

            % Second install must be a no-op.
            [installed, err] = installOnStaticClasspath(classpathFile, jar);
            mtime2 = dir(classpathFile).datenum;

            testCase.verifyFalse(installed);
            testCase.verifyEqual(err, "");
            testCase.verifyEqual(mtime2, mtime1, ...
                "File should not have been rewritten when up-to-date.");
        end

        function install_replacesStaleEntry(testCase)
            tmpDir = createTempDir(testCase);
            classpathFile = string(fullfile(tmpDir, 'javaclasspath.txt'));
            preExisting = [
                "# managed by yaml package";
                "C:\old-install\snakeyaml-1.30.jar";
                "C:\unrelated\other.jar"];
            writeLines(classpathFile, preExisting);

            jar = "C:\new-install\snakeyaml-1.30.jar";
            [installed, err] = installOnStaticClasspath(classpathFile, jar);

            testCase.verifyTrue(installed);
            testCase.verifyEqual(err, "");
            written = readLines(classpathFile);
            testCase.verifyEqual(written, [
                "# managed by yaml package";
                "C:\unrelated\other.jar";
                jar]);
        end

        function install_missingDirectory_returnsError(testCase)
            classpathFile = "C:\definitely\not\a\real\path\javaclasspath.txt";
            jar = "C:\pkg\snakeyaml-1.30.jar";

            [installed, err] = installOnStaticClasspath(classpathFile, jar);

            testCase.verifyFalse(installed);
            testCase.verifyTrue(strlength(err) > 0);
        end

        %% isJarOnJavaClasspath - regression for spurious javaaddpath warning

        function isJarOnClasspath_falseForUnrelatedPath(testCase)
            fakeJar = canonicalJavaPath("C:\definitely-not-real\fake.jar");
            testCase.verifyFalse(isJarOnJavaClasspath(fakeJar));
        end

        function isJarOnClasspath_findsExistingStaticEntry(testCase)
            % If javaclasspath('-static') reports any entry, the helper
            % must agree. Catches the bug where Class.forName-based
            % probes missed static-classpath entries because the JNI
            % caller's classloader differs from MATLAB's.
            staticEntries = string(javaclasspath('-static'));
            testCase.assumeFalse(isempty(staticEntries), ...
                'Static classpath empty - cannot fixture this test.');
            fixture = canonicalJavaPath(staticEntries(1));
            testCase.verifyTrue(isJarOnJavaClasspath(fixture));
        end

        function isJarOnClasspath_findsSnakeYamlAfterLoad(testCase)
            % Regression: after yaml.load runs once, the bundled
            % snakeyaml JAR must be detectable on the classpath.
            % Otherwise initializeSnakeYaml redundantly calls
            % javaaddpath on every subsequent session-start, producing
            % "already specified on java path" warnings on machines
            % where the static classpath has already absorbed the JAR.
            yaml.load("a: 1");

            pkgDir = fileparts(which('yaml.load'));
            jarPath = canonicalJavaPath(string(fullfile( ...
                pkgDir, 'snakeyaml', 'snakeyaml-1.30.jar')));

            testCase.verifyTrue(isJarOnJavaClasspath(jarPath));
        end

        %% End-to-end smoke tests

        function endToEnd_loadStillWorks(testCase)
            % Confirms that the rewritten initializeSnakeYaml does not
            % break the existing yaml.load contract. This call mutates
            % the user's real prefdir/javaclasspath.txt - that is the
            % point. The change is idempotent on subsequent runs.
            actual = yaml.load("a: 1");
            testCase.verifyEqual(actual, struct("a", 1));
        end

        function endToEnd_secondCallNoWarnings(testCase)
            % Regression for the "already specified on java path"
            % warning. Once yaml.load has run once in a session, a
            % second call must not emit *any* warning - the JAR is on
            % the classpath, the persistent flag is set, and there is
            % nothing left to do.
            yaml.load("a: 1");                       % warm-up
            lastwarn('', '');                         % clear warning state
            actual = yaml.load("a: 1");
            [msg, id] = lastwarn();
            testCase.verifyEqual(actual, struct("a", 1));
            testCase.verifyEmpty(msg, sprintf( ...
                'Unexpected warning on second yaml.load: [%s] %s', id, msg));
        end

    end
end

function tmpDir = createTempDir(testCase)
%CREATETEMPDIR Make a fresh empty directory for one test, auto-cleaned.
    tmpDir = tempname;
    mkdir(tmpDir);
    testCase.addTeardown(@() rmdir(tmpDir, 's'));
end

function writeLines(filePath, lines)
%WRITELINES Write a string array to FILEPATH with LF terminators.
    fid = fopen(char(filePath), "w");
    fprintf(fid, "%s\n", lines);
    fclose(fid);
end

function lines = readLines(filePath)
%READLINES Read FILEPATH back into a column string array of lines.
    raw = string(fileread(filePath));
    lines = splitlines(raw);
    if ~isempty(lines) && lines(end) == ""
        lines(end) = [];
    end
    lines = lines(:);
end
