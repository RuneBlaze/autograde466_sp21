#!/usr/bin/env ruby
#coding:utf-8
require_relative 'gradescope_util.rb'
require 'fileutils'
require 'set'

$res = {}

def crash! message
    $res = {}
    $res[:score] = 0
    $res[:output] = message
end

def produce_test_result score, maxscore, files, output
    $res[:tests] ||= []
    tests = $res[:tests]
    buf = ""
    files.each do |k, v|
        buf << "#{k}\n"
        buf << "==========="
        buf << File.read(v).strip()
        buf << "\n"
        buf << "<eof>\n"
    end
    buf << "your output: "
    buf << output
    buf << "\n"
    tests << {
        score: score,
        maxscore: maxscore,
        output: buf,
    }
end

class ExecutableWrapper
    def compile(fn, ext, executablename)
        @executablename = executablename
        case ext
        when ".py"
            fl = File.open(fn, &:readline)
            if fl.start_with?("#!") && fl.includes?("2.7")
                @lang = :py2
            else
                @lang = :py3
            end
        when ".java"
            @lang = :java
            `javac *.java`
        when ".cpp"
            @lang = :cpp
            `g++ -g -O2 -std=gnu++17 *.cpp -o #{executablename}`
        end
    end

    def execute(argv)
        case @lang
        when :py2
            `python #{@executablename}.py #{argv.join(' ')}`
        when :py3
            `python3 #{@executablename}.py #{argv.join(' ')}`
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


$root_tests = "/home/lbq/research/autograde466_sp21"
def run_assembly assemblyf
    aw = AssemblyWrapper.new(assemblyf, File.extname(assemblyf))
    for i in 1..8
        readpath = File.join $root_tests, "tests_assembly/reads#{i}.txt"
        outputpath = File.join $root_tests, "tests_assembly/reads#{i}.txt.out"
        score, output = *aw.run(readpath, outputpath)
        files = {
            "reads.txt" => readpath,
            "truth.txt" => outputpath,
        }
        produce_test_result score * 10, 10, files, output
    end
end

def run_blast blastf
    bw = BlastWrapper.new(blastf, File.extname(blastf))
    for i in 1..1
        queryp = File.join $root_tests, "tests_blast/queries#{i}.txt"
        dbp = File.join $root_tests, "tests_blast/db#{i}.txt"
        outp = File.join $root_tests, "tests_blast/queries#{i}.out"
        score, output = *bw.run(queryp, dbp, outp)
        files = {
            "queries.txt" => queryp,
            "db.txt" => dbp,
            "truth.txt" => outp,
        }
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
            crash! "No valid entry point found under directory."
            return
        end

        if assemblyf
            run_assembly assemblyf
            return
        end

        if blastf
            run_blast blastf
            return
        end
    end
end