import sys, re
src, out_nodes, out_rels = sys.argv[1], sys.argv[2], sys.argv[3]
id_re    = re.compile(r'\bid:\s*(-?\d+)')
comp_re  = re.compile(r'completion_percentage:\s*(-?\d+)')
gender_re= re.compile(r'gender:\s*"([^"]*)"')
age_re   = re.compile(r'\bage:\s*(-?\d+)')
edge_re  = re.compile(r'\bid:\s*(\d+)\D+?\bid:\s*(\d+)')
nn = ne = 0
fn = open(out_nodes, "w"); fr = open(out_rels, "w")
fn.write("id,completion_percentage,gender,age\n")
fr.write("src,dest\n")
for line in open(src):
    if line.startswith("CREATE (:User"):
        i = id_re.search(line)
        if not i: continue
        c = comp_re.search(line); g = gender_re.search(line); a = age_re.search(line)
        fn.write("%s,%s,%s,%s\n" % (i.group(1),
                                    c.group(1) if c else "",
                                    g.group(1) if g else "",
                                    a.group(1) if a else "")); nn += 1
    elif line.startswith("MATCH"):
        m = edge_re.search(line)
        if m:
            fr.write("%s,%s\n" % (m.group(1), m.group(2))); ne += 1
fn.close(); fr.close()
print("nodes=%d rels=%d" % (nn, ne))
