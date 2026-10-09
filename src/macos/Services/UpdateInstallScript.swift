import Foundation

enum UpdateInstallScript {
    static func make(installed: URL, staged: URL, backup: URL, work: URL, processID: Int32) -> String {
        let installedPath = quote(installed.path)
        let stagedPath = quote(staged.path)
        let backupPath = quote(backup.path)
        let workPath = quote(work.path)
        return """
        #!/bin/bash
        # Never replace a bundle while its old process is still alive. A fixed
        # sleep allowed open to reuse the stuck old process instead of relaunching.
        attempts=0
        while /bin/kill -0 \(processID) 2>/dev/null; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 600 ]; then
            echo 'Update cancelled: the application did not exit within 120 seconds.' >&2
            /bin/rm -rf \(stagedPath)
            exit 1
          fi
          /bin/sleep 0.2
        done
        if ! /bin/mv \(installedPath) \(backupPath); then
          /usr/bin/open \(installedPath) || true
          exit 1
        fi
        if /bin/mv \(stagedPath) \(installedPath); then
          if /usr/bin/open \(installedPath); then
            /bin/rm -rf \(backupPath) \(workPath)
          else
            /bin/mv \(installedPath) \(stagedPath) || true
            if /bin/mv \(backupPath) \(installedPath); then
              /usr/bin/open \(installedPath) || true
            fi
            /bin/rm -rf \(stagedPath) \(workPath)
            exit 1
          fi
        else
          if /bin/mv \(backupPath) \(installedPath); then
            /usr/bin/open \(installedPath) || true
          fi
          /bin/rm -rf \(stagedPath) \(workPath)
          exit 1
        fi
        """
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
