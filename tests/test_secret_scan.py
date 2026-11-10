"""Portable scanner regression tests; temporary Git repos and synthetic strings only."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'scripts' / 'secret-scan.sh'
KEY = 'sk-' + 'A' * 24

class SecretScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'repo'
        (self.root / 'scripts').mkdir(parents=True)
        shutil.copyfile(SOURCE, self.root / 'scripts/secret-scan.sh')
        self.env = {'PATH': '/usr/bin:/bin', 'HOME': self.temp.name,
                    'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': '/dev/null',
                    'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.invalid',
                    'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.invalid'}
        self.git('init', '-q', '-b', 'main')
        (self.root / 'sample.txt').write_text('harmless text\n')
        self.commit()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, env=self.env,
                              text=True, capture_output=True, check=True).stdout.strip()

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'fixture')

    def scan(self):
        return subprocess.run(['/bin/bash', 'scripts/secret-scan.sh'], cwd=self.root,
                              env=self.env, text=True, capture_output=True)

    def blocked(self):
        result = self.scan()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('SECRET SCAN: CLEAN', result.stdout)
        self.assertNotIn(KEY, result.stdout + result.stderr)
        return result

    def fake_tool(self, name, body):
        directory = Path(self.temp.name) / 'bin'
        directory.mkdir(exist_ok=True)
        file = directory / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)
        self.env['PATH'] = str(directory) + ':/usr/bin:/bin'

    def test_clean_repository(self):
        self.assertEqual(self.scan().returncode, 0)

    def test_git_error_is_not_clean(self):
        self.fake_tool('git', 'exit 128')
        self.blocked()

    def test_missing_repository_is_not_clean(self):
        shutil.rmtree(self.root / '.git')
        self.blocked()

    def test_shallow_repository_is_not_full_history(self):
        (self.root / '.git/shallow').write_text(self.git('rev-parse', 'HEAD') + '\n')
        self.blocked()

    def test_history_findings_are_redacted(self):
        (self.root / 'sample.txt').write_text(KEY)
        self.commit()
        (self.root / 'sample.txt').write_text('removed now\n')
        self.commit()
        self.blocked()

    def test_other_branch_is_scanned(self):
        self.git('checkout', '-qb', 'other')
        (self.root / 'sample.txt').write_text(KEY)
        self.commit()
        self.git('checkout', '-q', 'main')
        self.blocked()

    def test_unstaged_tracked_content_is_scanned(self):
        (self.root / 'sample.txt').write_text(KEY)
        self.blocked()

    def test_index_scanned_even_if_worktree_clean(self):
        (self.root / 'sample.txt').write_text(KEY)
        self.git('add', 'sample.txt')
        (self.root / 'sample.txt').write_text('harmless again\n')
        self.blocked()

    def test_empty_git_repository_can_be_scanned(self):
        self.git('checkout', '--orphan', 'empty')
        self.git('rm', '-rf', '--cached', '.')
        self.git('branch', '-D', 'main')
        self.assertEqual(self.scan().returncode, 0)

    def test_grep_failure_is_not_clean(self):
        self.fake_tool('git', 'if [ "$1" = grep ]; then exit 2; fi\nexec /usr/bin/git "$@"')
        self.blocked()

    def test_gitleaks_receives_redaction_and_all_refs(self):
        self.fake_tool('gitleaks', 'case " $* " in *" --redact "*) ;; *) exit 2;; esac\ncase " $* " in *" --log-opts=--all "*) exit 0;; *) exit 2;; esac')
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_history_enumeration_failure_is_not_clean(self):
        self.fake_tool('git', 'if [ "$1" = rev-list ]; then exit 128; fi\nexec /usr/bin/git "$@"')
        self.blocked()

    def test_gitleaks_findings_output_is_suppressed(self):
        self.fake_tool('gitleaks', 'echo "' + KEY + '"; echo "' + KEY + '" >&2; exit 1')
        self.blocked()

    def test_case_insensitive_candidate_is_blocked(self):
        (self.root / 'sample.txt').write_text('SK-' + 'A' * 24)
        self.blocked()

    def test_gitleaks_error_is_not_heuristic_fallback(self):
        self.fake_tool('gitleaks', 'exit 2')
        result = self.blocked()
        self.assertIn('ERROR', result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
