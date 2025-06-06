# vcs
require 'fileutils'
require 'optparse'
require 'pp'
require 'tempfile'

# This library is used by several other tools/ scripts to detect the current
# VCS in use (e.g. SVN, Git) or to interact with that VCS.

ENV.delete('PWD')

class VCS
  DEBUG_OUT = STDERR.dup

  def self.dump(obj, pre = nil)
    out = DEBUG_OUT
    @pp ||= PP.new(out)
    @pp.guard_inspect_key do
      if pre
        @pp.group(pre.size, pre) {
          obj.pretty_print(@pp)
        }
      else
        obj.pretty_print(@pp)
      end
      @pp.flush
      out << "\n"
    end
  end
end

unless File.respond_to? :realpath
  require 'pathname'
  def File.realpath(arg)
    Pathname(arg).realpath.to_s
  end
end

def IO.pread(*args)
  VCS.dump(args, "args: ") if $DEBUG
  popen(*args) {|f|f.read}
end

module DebugPOpen
  refine IO.singleton_class do
    def popen(*args)
      VCS.dump(args, "args: ") if $DEBUG
      super
    end
  end
end
using DebugPOpen
module DebugSystem
  def system(*args)
    VCS.dump(args, "args: ") if $DEBUG
    exception = false
    opts = Hash.try_convert(args[-1])
    if RUBY_VERSION >= "2.6"
      unless opts
        opts = {}
        args << opts
      end
      exception = opts.fetch(:exception) {opts[:exception] = true}
    elsif opts
      exception = opts.delete(:exception) {true}
      args.pop if opts.empty?
    end
    ret = super(*args)
    raise "Command failed with status (#$?): #{args[0]}" if exception and !ret
    ret
  end
end

class VCS
  prepend(DebugSystem) if defined?(DebugSystem)
  class NotFoundError < RuntimeError; end

  @@dirs = []
  def self.register(dir, &pred)
    @@dirs << [dir, self, pred]
  end

  def self.detect(path = '.', options = {}, parser = nil, **opts)
    options.update(opts)
    uplevel_limit = options.fetch(:uplevel_limit, 0)
    curr = path
    begin
      @@dirs.each do |dir, klass, pred|
        if pred ? pred[curr, dir] : File.directory?(File.join(curr, dir))
          if klass.const_defined?(:COMMAND)
            IO.pread([{'LANG' => 'C', 'LC_ALL' => 'C'}, klass::COMMAND, "--version"]) rescue next
          end
          vcs = klass.new(curr)
          vcs.define_options(parser) if parser
          vcs.set_options(options)
          return vcs
        end
      end
      if uplevel_limit
        break if uplevel_limit.zero?
        uplevel_limit -= 1
      end
      prev, curr = curr, File.realpath(File.join(curr, '..'))
    end until curr == prev # stop at the root directory
    raise VCS::NotFoundError, "does not seem to be under a vcs: #{path}"
  end

  def self.local_path?(path)
    String === path or path.respond_to?(:to_path)
  end

  def self.define_options(parser, opts = {})
    parser.separator("  VCS common options:")
    parser.define("--[no-]dryrun") {|v| opts[:dryrun] = v}
    parser.define("--[no-]debug") {|v| opts[:debug] = v}
    parser.define("-z", "--zone=OFFSET", /\A[-+]\d\d:\d\d\z/) {|v| opts[:zone] = v}
    opts
  end

  def release_date(time)
    t = time.getlocal(@zone)
    [
      t.strftime('#define RUBY_RELEASE_YEAR %Y'),
      t.strftime('#define RUBY_RELEASE_MONTH %-m'),
      t.strftime('#define RUBY_RELEASE_DAY %-d'),
    ]
  end

  def self.short_revision(rev)
    rev
  end

  attr_reader :srcdir

  def initialize(path)
    @srcdir = path
    super()
  end

  def chdir(path)
    @srcdir = path
  end

  def define_options(parser)
  end

  def set_options(opts)
    @debug = opts.fetch(:debug) {$DEBUG}
    @dryrun = opts.fetch(:dryrun) {@debug}
    @zone = opts.fetch(:zone) {'+09:00'}
  end

  attr_reader :dryrun, :debug
  alias dryrun? dryrun
  alias debug? debug

  NullDevice = IO::NULL

  # returns
  # * the last revision of the current branch
  # * the last revision in which +path+ was modified
  # * the last modified time of +path+
  # * the last commit title since the latest upstream
  def get_revisions(path)
    if self.class.local_path?(path)
      path = relative_to(path)
    end
    last, changed, modified, *rest = (
      begin
        if NullDevice and !debug?
          save_stderr = STDERR.dup
          STDERR.reopen NullDevice, 'w'
        end
        _get_revisions(path, @srcdir)
      rescue Errno::ENOENT => e
        raise VCS::NotFoundError, e.message
      ensure
        if save_stderr
          STDERR.reopen save_stderr
          save_stderr.close
        end
      end
    )
    last or raise VCS::NotFoundError, "last revision not found"
    changed or raise VCS::NotFoundError, "changed revision not found"
    if modified
      /\A(\d+)-(\d+)-(\d+)\D(\d+):(\d+):(\d+(?:\.\d+)?)\s*(?:Z|([-+]\d\d)(\d\d))\z/ =~ modified or
        raise "unknown time format - #{modified}"
      match = $~[1..6].map { |x| x.to_i }
      off = $7 ? "#{$7}:#{$8}" : "+00:00"
      match << off
      begin
        modified = Time.new(*match)
      rescue ArgumentError
        modified = Time.utc(*$~[1..6]) + $7.to_i * 3600 + $8.to_i * 60
      end
      modified = modified.getlocal(@zone)
    end
    return last, changed, modified, *rest
  end

  def modified(path)
    _, _, modified, * = get_revisions(path)
    modified
  end

  def relative_to(path)
    if path
      srcdir = File.realpath(@srcdir)
      path = File.realdirpath(path)
      list1 = srcdir.split(%r{/})
      list2 = path.split(%r{/})
      while !list1.empty? && !list2.empty? && list1.first == list2.first
        list1.shift
        list2.shift
      end
      if list1.empty? && list2.empty?
        "."
      else
        ([".."] * list1.length + list2).join("/")
      end
    else
      '.'
    end
  end

  def after_export(dir)
    FileUtils.rm_rf(Dir.glob("#{dir}/.git*"))
    FileUtils.rm_rf(Dir.glob("#{dir}/.mailmap"))
  end

  def revision_handler(rev)
    self.class
  end

  def revision_name(rev)
    revision_handler(rev).revision_name(rev)
  end

  def short_revision(rev)
    revision_handler(rev).short_revision(rev)
  end

  # make-snapshot generates only release_date whereas file2lastrev generates both release_date and release_datetime
  def revision_header(last, release_date, release_datetime = nil, branch = nil, title = nil, limit: 20)
    short = short_revision(last)
    if /[^\x00-\x7f]/ =~ title and title.respond_to?(:force_encoding)
      title = title.dup.force_encoding("US-ASCII")
    end
    code = [
      "#define RUBY_REVISION #{short.inspect}",
    ]
    unless short == last
      code << "#define RUBY_FULL_REVISION #{last.inspect}"
    end
    if branch
      e = '..'
      name = branch.sub(/\A(.{#{limit-e.size}}).{#{e.size+1},}/o) {$1+e}
      name = name.dump.sub(/\\#/, '#')
      code << "#define RUBY_BRANCH_NAME #{name}"
    end
    if title
      title = title.dump.sub(/\\#/, '#')
      code << "#define RUBY_LAST_COMMIT_TITLE #{title}"
    end
    if release_datetime
      t = release_datetime.utc
      code << t.strftime('#define RUBY_RELEASE_DATETIME "%FT%TZ"')
    end
    code += self.release_date(release_date)
    code
  end

  class GIT < self
    register(".git") do |path, dir|
      SAFE_DIRECTORIES ||=
        begin
          command = ENV["GIT"] || 'git'
          dirs = IO.popen(%W"#{command} config --global --get-all safe.directory", &:read).split("\n")
        rescue
          command = nil
          dirs = []
        ensure
          VCS.dump(dirs, "safe.directory: ") if $DEBUG
          COMMAND = command
        end

      COMMAND and File.exist?(File.join(path, dir))
    end

    def cmd_args(cmds, srcdir = nil)
      (opts = cmds.last).kind_of?(Hash) or cmds << (opts = {})
      opts[:external_encoding] ||= "UTF-8"
      if srcdir
        opts[:chdir] ||= srcdir
      end
      VCS.dump(cmds, "cmds: ") if debug? and !$DEBUG
      cmds
    end

    def cmd_pipe_at(srcdir, cmds, &block)
      without_gitconfig { IO.popen(*cmd_args(cmds, srcdir), &block) }
    end

    def cmd_read_at(srcdir, cmds)
      result = without_gitconfig { IO.pread(*cmd_args(cmds, srcdir)) }
      VCS.dump(result, "result: ") if debug?
      result
    end

    def cmd_pipe(*cmds, &block)
      cmd_pipe_at(@srcdir, cmds, &block)
    end

    def cmd_read(*cmds)
      cmd_read_at(@srcdir, cmds)
    end

    def svn_revision(log)
      if /^ *git-svn-id: .*@(\d+) .*\n+\z/ =~ log
        $1.to_i
      end
    end

    def _get_revisions(path, srcdir = nil)
      ref = Branch === path ? path.to_str : 'HEAD'
      gitcmd = [COMMAND]
      last = nil
      IO.pipe do |r, w|
        last = cmd_read_at(srcdir, [[*gitcmd, 'rev-parse', ref, err: w]]).rstrip
        w.close
        unless r.eof?
          raise VCS::NotFoundError, "#{COMMAND} rev-parse failed\n#{r.read.gsub(/^(?=\s*\S)/, '  ')}"
        end
      end
      log = cmd_read_at(srcdir, [[*gitcmd, 'log', '-n1', '--date=iso', '--pretty=fuller', *path]])
      changed = log[/\Acommit (\h+)/, 1]
      modified = log[/^CommitDate:\s+(.*)/, 1]
      if rev = svn_revision(log)
        if changed == last
          last = rev
        else
          svn_rev = svn_revision(cmd_read_at(srcdir, [[*gitcmd, 'log', '-n1', '--format=%B', last]]))
          last = svn_rev if svn_rev
        end
        changed = rev
      end
      branch = cmd_read_at(srcdir, [gitcmd + %W[symbolic-ref --short #{ref}]])
      if branch.empty?
        branch = cmd_read_at(srcdir, [gitcmd + %W[describe --contains #{ref}]]).strip
      end
      if branch.empty?
        branch_list = cmd_read_at(srcdir, [gitcmd + %W[branch --list --contains #{ref}]]).lines.to_a
        branch, = branch_list.grep(/\A\*/)
        case branch
        when /\A\* *\(\S+ detached at (.*)\)\Z/
          branch = $1
          branch = nil if last.start_with?(branch)
        when /\A\* (\S+)\Z/
          branch = $1
        else
          branch = nil
        end
        unless branch
          branch_list.each {|b| b.strip!}
          branch_list.delete_if {|b| / / =~ b}
          branch = branch_list.min_by(&:length) || ""
        end
      end
      branch.chomp!
      branch = ":detached:" if branch.empty?
      upstream = cmd_read_at(srcdir, [gitcmd + %W[branch --list --format=%(upstream:short) #{branch}]])
      upstream.chomp!
      title = cmd_read_at(srcdir, [gitcmd + %W[log --format=%s -n1 #{upstream}..#{ref}]])
      title = nil if title.empty?
      [last, changed, modified, branch, title]
    end

    def self.revision_name(rev)
      short_revision(rev)
    end

    def self.short_revision(rev)
      rev[0, 10]
    end

    def without_gitconfig
      envs = (%w'HOME XDG_CONFIG_HOME' + ENV.keys.grep(/\AGIT_/)).each_with_object({}) do |v, h|
        h[v] = ENV.delete(v)
      end
      ENV['GIT_CONFIG_SYSTEM'] = NullDevice
      ENV['GIT_CONFIG_GLOBAL'] = global_config
      yield
    ensure
      ENV.update(envs)
    end

    def global_config
      return NullDevice if SAFE_DIRECTORIES.empty?
      unless @gitconfig
        @gitconfig = Tempfile.new(%w"vcs_ .gitconfig")
        @gitconfig.close
        ENV['GIT_CONFIG_GLOBAL'] = @gitconfig.path
        SAFE_DIRECTORIES.each do |dir|
          system(*%W[#{COMMAND} config --global --add safe.directory #{dir}])
        end
        VCS.dump(`#{COMMAND} config --global --get-all safe.directory`, "safe.directory: ") if debug?
      end
      @gitconfig.path
    end

    def initialize(*)
      super
      @srcdir = File.realpath(@srcdir)
      @gitconfig = nil
      VCS.dump(@srcdir, "srcdir: ") if debug?
      self
    end

    Branch = Struct.new(:to_str)

    def branch(name)
      Branch.new(name)
    end

    alias tag branch

    def master
      branch("master")
    end
    alias trunk master

    def stable
      cmd = %W"#{COMMAND} for-each-ref --format=\%(refname:short) refs/heads/ruby_[0-9]*"
      branch(cmd_read(cmd)[/.*^(ruby_\d+_\d+)$/m, 1])
    end

    def branch_list(pat)
      cmd = %W"#{COMMAND} for-each-ref --format=\%(refname:short) refs/heads/#{pat}"
      cmd_pipe(cmd) {|f|
        f.each {|line|
          line.chomp!
          yield line
        }
      }
    end

    def grep(pat, tag, *files, &block)
      cmd = %W[#{COMMAND} grep -h --perl-regexp #{tag} --]
      set = block.binding.eval("proc {|match| $~ = match}")
      cmd_pipe(cmd+files) do |f|
        f.grep(pat) do |s|
          set[$~]
          yield s
        end
      end
    end

    def export(revision, url, dir, keep_temp = false)
      system(COMMAND, "clone", "-c", "advice.detachedHead=false", "-s", (@srcdir || '.').to_s, "-b", url, dir) or return
      GIT.new(File.expand_path(dir))
    end

    def branch_beginning(url)
      cmd_read(%W[ #{COMMAND} log -n1 --format=format:%H
                   --author=matz --committer=matz --grep=started\\.$
                   #{url.to_str} -- version.h include/ruby/version.h])
    end

    def export_changelog(url = '@', from = nil, to = nil, _path = nil, path: _path, base_url: nil)
      from, to = [from, to].map do |rev|
        rev or next
        rev unless rev.empty?
      end
      unless (from && /./.match(from)) or ((from = branch_beginning(url)) && /./.match(from))
        warn "no starting commit found", uplevel: 1
        from = nil
      end
      if system(*%W"#{COMMAND} fetch origin refs/notes/commits:refs/notes/commits",
                           chdir: @srcdir, exception: false)
        system(*%W"#{COMMAND} fetch origin refs/notes/log-fix:refs/notes/log-fix",
               chdir: @srcdir, exception: false)
      else
        warn "Could not fetch notes/commits tree", uplevel: 1
      end
      to ||= url.to_str
      if from
        arg = ["#{from}^..#{to}"]
      else
        arg = ["--since=25 Dec 00:00:00", to]
      end
      if base_url == true
        remote, = upstream
        if remote &&= cmd_read(env, %W[#{COMMAND} remote get-url --no-push #{remote}])
          remote.chomp!
          # hack to redirect git.r-l.o to github
          remote.sub!(/\Agit@git\.ruby-lang\.org:/, 'git@github.com:ruby/')
          remote.sub!(/\Agit@(.*?):(.*?)(?:\.git)?\z/, 'https://\1/\2/commit/')
        end
        base_url = remote
      end
      writer = changelog_formatter(path, arg, base_url)
      if !path or path == '-'
        writer[$stdout]
      else
        File.open(path, 'wb', &writer)
      end
    end

    LOG_FIX_REGEXP_SEPARATORS = '/!:;|,#%&'

    def changelog_formatter(path, arg, base_url = nil)
      env = {'TZ' => 'JST-9', 'LANG' => 'C', 'LC_ALL' => 'C'}
      cmd = %W[#{COMMAND} log
        --format=fuller --notes=commits --notes=log-fix --topo-order --no-merges
        --fixed-strings --invert-grep --grep=[ci\ skip] --grep=[skip\ ci]
      ]
      date = "--date=iso-local"
      unless system(env, *cmd, date, "-1", chdir: @srcdir, out: NullDevice, exception: false)
        date = "--date=iso"
      end
      cmd << date
      cmd.concat(arg)
      proc do |w|
        w.print "-*- coding: utf-8 -*-\n"
        w.print "\n""base-url = #{base_url}\n" if base_url

        begin
          ignore_revs = File.readlines(File.join(@srcdir, ".git-blame-ignore-revs"), chomp: true)
                          .grep_v(/^ *(?:#|$)/)
                          .to_h {|v| [v, true]}
          ignore_revs = nil if ignore_revs.empty?
        rescue Errno::ENOENT
        end

        cmd_pipe(env, cmd, chdir: @srcdir) do |r|
          r.gets(sep = "commit ")
          sep = "\n" + sep
          while s = r.gets(sep, chomp: true)
            h, s = s.split(/^$/, 2)
            if ignore_revs&.key?(h[/\A\h{40}/])
              next
            end

            next if /^Author: *dependabot\[bot\]/ =~ h

            h.gsub!(/^(?:(?:Author|Commit)(?:Date)?|Date): /, '  \&')
            if s.sub!(/\nNotes \(log-fix\):\n((?: +.*\n)+)/, '')
              fix = $1
              next if /\A *skip\Z/ =~ fix
              s = s.lines
              fix.each_line do |x|
                next unless x.sub!(/^(\s+)(?:(\d+)|\$(?:-\d+)?)/, '')
                b = ($2&.to_i || (s.size - 1 + $3.to_i))
                sp = $1
                if x.sub!(/^,(?:(\d+)|\$(?:-\d+)?)/, '')
                  range = b..($1&.to_i || (s.size - 1 + $2.to_i))
                else
                  range = b..b
                end
                case x
                when %r[^s([#{LOG_FIX_REGEXP_SEPARATORS}])(.+)\1(.*)\1([gr]+)?]o
                  wrong = $2
                  correct = $3
                  if opt = $4 and opt.include?("r") # regexp
                    wrong = Regexp.new(wrong)
                    correct.gsub!(/(?<!\\)(?:\\\\)*\K(?:\\n)+/) {"\n" * ($&.size / 2)}
                    sub = opt.include?("g") ? :gsub! : :sub!
                  else
                    sub = false
                  end
                  range.each do |n|
                    if sub
                      ss = s[n].sub(/^#{sp}/, "") # un-indent for /^/
                      if ss.__send__(sub, wrong, correct)
                        s[n, 1] = ss.lines.map {|l| "#{sp}#{l}"}
                        next
                      end
                    else
                      begin
                        s[n][wrong] = correct
                      rescue IndexError
                      else
                        next
                      end
                    end
                    message = ["changelog_formatter failed to replace #{wrong.dump} with #{correct.dump} at #{n}\n"]
                    from = [1, n-2].max
                    to = [s.size-1, n+2].min
                    s.each_with_index do |e, i|
                      next if i < from
                      break if to < i
                      message << "#{i}:#{e}"
                    end
                    raise message.join('')
                  end
                when %r[^i([#{LOG_FIX_REGEXP_SEPARATORS}])(.*)\1]o
                  insert = "#{sp}#{$2}\n"
                  range.reverse_each do |n|
                    s[n, 0] = insert
                  end
                when %r[^d]
                  s[range] = []
                end
              end
              s = s.join('')
            end

            if %r[^ +(https://github\.com/[^/]+/[^/]+/)commit/\h+\n(?=(?: +\n(?i: +Co-authored-by: .*\n)+)?(?:\n|\Z))] =~ s
              issue = "#{$1}pull/"
              s.gsub!(/\b(?:(?i:fix(?:e[sd])?) +|GH-)\K#(?=\d+\b)|\(\K#(?=\d+\))/) {issue}
            end

            s.gsub!(/ +\n/, "\n")
            s.sub!(/^Notes:/, '  \&')
            w.print sep, h, s
          end
        end
      end
    end

    def upstream
      (branch = cmd_read(%W"#{COMMAND} symbolic-ref --short HEAD")).chomp!
      (upstream = cmd_read(%W"#{COMMAND} branch --list --format=%(upstream) #{branch}")).chomp!
      while ref = upstream[%r"\Arefs/heads/(.*)", 1]
        upstream = cmd_read(%W"#{COMMAND} branch --list --format=%(upstream) #{ref}")
      end
      unless %r"\Arefs/remotes/([^/]+)/(.*)" =~ upstream
        raise "Upstream not found"
      end
      [$1, $2]
    end

    def commit(opts = {})
      args = [COMMAND, "push"]
      args << "-n" if dryrun?
      remote, branch = upstream
      args << remote
      branches = %W[refs/notes/commits:refs/notes/commits HEAD:#{branch}]
      if dryrun?
        branches.each do |b|
          VCS.dump(args + [b], "commit: ")
        end
        return true
      end
      branches.each do |b|
        system(*(args + [b])) or return false
      end
      true
    end
  end

  class Null < self
    def get_revisions(path, srcdir = nil)
      @modified ||= Time.now - 10
      return nil, nil, @modified
    end

    def revision_header(last, release_date, release_datetime = nil, branch = nil, title = nil, limit: 20)
      self.release_date(release_date)
    end
  end
end
