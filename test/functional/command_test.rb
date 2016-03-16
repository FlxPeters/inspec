# encoding: utf-8
# author: Dominik Richter
# author: Christoph Hartmann

require 'helper'
require 'train'

# activate hell!
require 'minitest/hell'
class Minitest::Test
  parallelize_me!
end

CMD = Train.create('local').connection

describe 'Inspec::InspecCLI' do
  let(:repo_path) { File.expand_path(File.join( __FILE__, '..', '..', '..')) }
  let(:exec_inspec) { File.join(repo_path, 'bin', 'inspec') }
  let(:profile_path) { File.join(repo_path, 'test', 'unit', 'mock', 'profiles') }
  let(:examples_path) { File.join(repo_path, 'examples') }
  let(:dst) {
    # create a temporary path, but we only want an auto-clean helper
    # so remove the file and give back the path
    res = Tempfile.new('inspec-shred')
    FileUtils.rm(res.path)
    res
  }

  def inspec(commandline)
    CMD.run_command("#{exec_inspec} #{commandline}")
  end

  describe 'example profile' do
    let(:path) { File.join(examples_path, 'profile') }

    it 'check is successful' do
      out = inspec('check ' + path)
      out.stdout.must_match /Valid.*true/
      out.exit_status.must_equal 0
    end

    it 'archive is successful' do
      out = inspec('archive ' + path + ' --overwrite')
      out.exit_status.must_equal 0
      out.stdout.must_match /Generate archive [^ ]*profile.tar.gz/
      out.stdout.must_include 'Finished archive generation.'
    end

    it 'archives to output file' do
      out = inspec('archive ' + path + ' --output ' + dst.path)
      out.stderr.must_equal ''
      out.stdout.must_include 'Generate archive '+dst.path
      out.stdout.must_include 'Finished archive generation.'
      out.exit_status.must_equal 0
      File.exist?(dst.path).must_equal true
    end

    it 'auto-archives when no --output is given' do
      auto_dst = File.join(repo_path, 'profile.tar.gz')
      out = inspec('archive ' + path + ' --overwrite')
      out.stderr.must_equal ''
      out.stdout.must_include 'Generate archive '+auto_dst
      out.stdout.must_include 'Finished archive generation.'
      out.exit_status.must_equal 0
      File.exist?(auto_dst).must_equal true
    end

    it 'archive on invalid archive' do
      out = inspec('archive /proc --output ' + dst.path)
      # out.stdout.must_equal '' => we have partial stdout output right now
      out.stderr.must_include "Don't understand inspec profile in \"/proc\""
      out.exit_status.must_equal 1
      File.exist?(dst.path).must_equal false
    end

    it 'archive wont overwrite existing files' do
      x = rand.to_s
      File.write(dst.path, x)
      out = inspec('archive ' + path + ' --output ' + dst.path)
      out.stderr.must_equal '' # uh...
      out.stdout.must_include "Archive #{dst.path} exists already. Use --overwrite."
      out.exit_status.must_equal 1
      File.read(dst.path).must_equal x
    end

    it 'archive will overwrite files if necessary' do
      x = rand.to_s
      File.write(dst.path, x)
      out = inspec('archive ' + path + ' --output ' + dst.path + ' --overwrite')
      out.stderr.must_equal '' # uh...
      out.stdout.must_include 'Generate archive '+dst.path
      out.exit_status.must_equal 0
      File.read(dst.path).wont_equal x
    end

  end

  describe 'example inheritance profile' do
    let(:path) { File.join(examples_path, 'inheritance') }

    it 'check fails without --profiles-path' do
      out = inspec('check ' + path)
      out.stderr.must_include 'You must supply a --profiles-path to inherit'
      out.stdout.must_equal ''
      out.exit_status.must_equal 1
    end

    it 'check succeeds with --profiles-path' do
      out = inspec('check ' + path + ' --profiles-path ' + examples_path)
      out.stderr.must_equal ''
      out.stdout.must_match /Valid.*true/
      out.exit_status.must_equal 0
    end

    it 'archive fails without --profiles-path' do
      out = inspec('archive ' + path + ' --output ' + dst.path)
      # out.stdout.must_equal '' => we have partial stdout output right now
      out.stderr.must_include 'You must supply a --profiles-path to inherit'
      out.exit_status.must_equal 1
      File.exist?(dst.path).must_equal false
    end

    it 'archive is successful with --profiles-path' do
      out = inspec('archive ' + path + ' --output ' + dst.path + ' --profiles-path ' + examples_path)
      out.stderr.must_equal ''
      out.stdout.must_include 'Generate archive '+dst.path
      out.stdout.must_include 'Finished archive generation.'
      out.exit_status.must_equal 0
      File.exist?(dst.path).must_equal true
    end
  end
end
