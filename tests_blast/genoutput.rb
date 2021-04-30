for i in 1..10
    File.open("queries#{i}.out", "w+") do |f|
        res = `blastn -word_size 11 -query queries#{i}.fa -subject db#{i}.fa -outfmt "10 qseqid qstart qend sstart send"`
        f.print(res)
    end
end