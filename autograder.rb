#!/usr/bin/env ruby
#coding:utf-8
require_relative 'gradescope_util.rb'
require 'fileutils'
require 'set'
require 'stringio'

$res = {}
$output = StringIO.new
def crash! message
    $res = {}
    $res[:score] = 0
    $output.puts("🔥 #{message}")
end

def produce_test_crash maxscore, files
    $res[:tests] ||= []
    io = StringIO.new
    tests = $res[:tests]
    index = tests.size+1
    io.puts "🗃️ Test Case (Crashed) ##{index}"
    io.puts ""
    files.each do |k, v|
        io.puts "  📄#{k}: #{File.basename(v.strip())}"
        # buf << File.read(v).strip()
        # buf << "\n"
        # buf << "<eof>\n"
    end
    io.puts ""
    io.puts "❌ Your program crashed! See stdout for more information. "
    io.puts "✒️ Score: #{0}/#{maxscore}"
    # buf << "your output: "
    # buf << output
    # buf << "\n"

    tests << {
        name: "Test #{index}",
        score: 0,
        maxscore: maxscore,
        output: io.string,
    }
end

def produce_test_result score, maxscore, files, output
    $res[:tests] ||= []
    io = StringIO.new
    tests = $res[:tests]
    index = tests.size+1
    io.puts "🗃️ Test Case ##{index}"
    io.puts ""
    files.each do |k, v|
        io.puts "  📄#{k}: #{File.basename(v.strip())}"
        # buf << File.read(v).strip()
        # buf << "\n"
        # buf << "<eof>\n"
    end
    io.puts ""
    io.puts "📝 Your Output: "
    io.puts output
    io.puts ""
    io.puts "✒️ Score: #{score.round(2)}/#{maxscore}"
    # buf << "your output: "
    # buf << output
    # buf << "\n"
    if score == maxscore
        io.puts "💯"
    elsif score == 0
        io.puts "⚠️ Scored 0 on this test case. Double check the behavior of your code."
    end
    tests << {
        name: "Test #{index}",
        score: score,
        maxscore: maxscore,
        output: io.string,
    }
end

class ExecutableWrapper
    attr_reader :lang
    def compile(fn, ext, executablename)
        @executablename = executablename
        
        case ext
        when ".py"
            fl = File.open(fn, &:readline)
            if fl.start_with?("#!") && fl.include?("2.7")
                @lang = :py2
            else
                @lang = :py3
            end
        when ".java"
            @lang = :java
            if File.exists?("Makefile")
                `make`
            else
                `javac *.java`
            end
        when ".cpp"
            @lang = :cpp
            if File.exists?("Makefile")
                `make`
            else
                `g++ -g -O2 -std=gnu++17 *.cpp -o #{executablename}`
            end
        end
    end

    def execute(argv)
        case @lang
        when :py2
            `python2.7 #{@executablename}.py #{argv.join(' ')}`
        when :py3
            `python3.8 #{@executablename}.py #{argv.join(' ')}`
        when :java
            `java #{@executablename.capitalize} #{argv.join(' ')}`
        when :cpp
            `./#{@executablename} #{argv.join(' ')}`
        end
    end
end

class AssemblyWrapper < ExecutableWrapper
    def initialize(fn, ext)
        compile(fn, ext, "assembly")
    end

    def run(inputf, outputf) # returns whether the result is valid
        res = execute([inputf])
        res.strip!
        
        expectedout = File.read(outputf).strip
        
        if expectedout == "-1"
            return res == expectedout ? 1 : 0, res
        end
        reads = File.readlines(inputf)
        n = res.size
        k = reads[0].strip.size
        counts = {}
        for i in 0...(n-k+1)
            kmer = res[i...(i+k)]
            counts[kmer] ||= 0
            counts[kmer] += 1
        end
        counts2 = {}
        reads.each do |r|
            r.strip!
            counts2[r] ||= 0
            counts2[r] += 1
        end
        return [counts == counts2 ? 1 : 0, res]
    end
end

class BlastWrapper < ExecutableWrapper
    def initialize(fn, ext)
        compile(fn, ext, "blast")
    end

    def parseoutput str
        parsedout = []
        str.each_line do |l|
            
            parsedout << l.strip.split(",").map(&:to_i)
        end
        parsedout
    end

    def run(queryf, dbf, outputf)
        res = execute([queryf, dbf])
        res.strip!
        expectedout = Set.new parseoutput(File.read(outputf).strip)
        resout = Set.new parseoutput(res)
        nonhits = expectedout - resout
        [1 - nonhits.size / expectedout.size.to_f, res]
    end
end


def print_header topic, lang
    $output.puts " ✨ Autograder Started"
    $output.puts "   The autograder does not currently support build tools."
    $output.puts "   If you purposefully do not use the simplest project configuration, the autograder will not be that useful."
    $output.puts "   Ignore the autograder results if you do not conform to the standard project configuration or language."
    $output.puts "   See the Piazza post about the autograder for more information."
    $output.puts ""
    $output.puts "   Assembly test cases: https://github.com/RuneBlaze/autograde466_sp21/tree/main/tests_assembly"
    $output.puts "   BLAST test cases: https://github.com/RuneBlaze/autograde466_sp21/tree/main/tests_blast"
    $output.puts "   The BLAST test cases can be overly stringent."
    $output.puts "   If your output looks meaningful and correct under your parameters, don't worry about the scores."
    $output.puts ""
    $output.puts "   🧳 Project Option: #{topic}"
    $output.puts "   🌐 Project Language Adapter: #{lang}"
    $output.puts ""
    $output.puts " 🌎 Environment Configuration"
    # $output.puts "   #{`python2.7 -c 'import sys; print(sys.version)'`}"
    $output.puts "   #{`python3.8 --version`}"
    $output.puts "   #{`java -version`}"
    $output.puts "   #{`g++ --version | head -n 1`}"
    $output.puts "   NetworkX (pip2): #{`python2.7 -m pip show networkx | grep Version: `}"
    $output.puts "   NetworkX (pip3): #{`python3.8 -m pip show networkx | grep Version: `}"
end


$root_tests = "/home/lbq/research/autograde466_sp21"
def run_assembly assemblyf
    points = 12.5
    aw = AssemblyWrapper.new(assemblyf, File.extname(assemblyf))
    print_header "assembly", aw.lang
    for i in 1..8
        readpath = File.join $root_tests, "tests_assembly/reads#{i}.txt"
        outputpath = File.join $root_tests, "tests_assembly/reads#{i}.txt.out"
        score, output = *aw.run(readpath, outputpath)
        
        files = {
            "reads" => readpath,
            "truth" => outputpath,
        }
        if !$?.success?
            produce_test_crash points, files
            next
        end
        produce_test_result score * points, points, files, output
    end
end

def run_blast blastf
    bw = BlastWrapper.new(blastf, File.extname(blastf))
    print_header "blast", bw.lang
    for i in 1..10
        queryp = File.join $root_tests, "tests_blast/queries#{i}.txt"
        dbp = File.join $root_tests, "tests_blast/db#{i}.txt"
        outp = File.join $root_tests, "tests_blast/queries#{i}.out"
        score, output = *bw.run(queryp, dbp, outp)
        
        files = {
            "queries" => queryp,
            "db" => dbp,
            "truth" => outp,
        }
        if !$?.success?
            produce_test_crash 10, files
            next
        end
        produce_test_result score * 10, 10, files, output
    end
end


def run_tests root
    Dir.chdir(root) do
        assembly_candidates = Dir.glob('[Aa]ssembly.*')
        
        blast_candidates = Dir.glob('[Bb]last.*')

        supported_extensions = [".py", ".c", ".cpp", ".java"]
        assemblyf = assembly_candidates.detect {|f| supported_extensions.include?(File.extname(f))}
        blastf = blast_candidates.detect {|f| supported_extensions.include?(File.extname(f))}
        if assemblyf && blastf
            # absurd!
            crash! "Cannot discern project options: #{assemblyf} #{blastf}."
            return
        end

        if !assemblyf && !blastf
            msg = "No valid entry point found under directory: \n#{Dir.glob('*').join('\n')}\n"
            msg << "It could be that your project uses a different convention.\n"
            msg << "If that is the case, as long as you documented how to run your code, your submission is entirely valid.\n"
            msg << "(Just not checked by the autograder.)\n"
            crash! msg
            return
        end

        begin
            if assemblyf
                run_assembly assemblyf
                return
            end
    
            if blastf
                run_blast blastf
                return
            end
        rescue RuntimeError => e
            crash! "RuntimeError: #{e.message}"
            $output.puts caller
        rescue => e
            crash! "Autograder Crashed."
            $output.puts "It could be that your code did not compile."
            $output.puts "If there are no compilation errors in the autograder output,"
            $output.puts "share the link to this page with me (baqiaol2@illinois.edu)."
            $output.puts e.message
            $output.puts caller
        else
        end
    end
end