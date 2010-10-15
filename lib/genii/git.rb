module Git
  def git_clone(repository_url, options={})
    # Make sure we have the host key cached
    user_at_host = repository_url.split(':', 2).first
    execute("ssh -o 'StrictHostKeyChecking=no' " + \
            "-o 'PasswordAuthentication=no' #{user_at_host} hostname",
            :ignore_error => true)
    execute("git clone #{repository_url} #{options[:to]}", :cwd => options[:cwd])
  end

  def git_checkout(branch, options={})
    execute("git checkout #{options[:from] || "HEAD"} && git checkout -b #{branch}",
            :cwd => options[:cwd])
  end

  def git_enable_submodules(directory)
    execute("git submodule init && git submodule sync && git submodule update",
            :cwd => directory)
  end

  def git_revision(directory, branch)
    execute("git rev-list --max-count=1 #{branch}",
            :cwd => directory).output
  end
end
