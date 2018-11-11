require "vcdiff-compiler"

function run_test_window(stream)
	new_window()
	.run(10, 'r')
	.run(5, '<run test>')
	.write_to(stream)
end

function add_test_window(stream)
	new_window()
	.add('>add test<')
	.write_to(stream)
end

function copy_test_window(stream)
	new_window(16, 928)
	.copy(16, 0)
	.copy(16, -16)
	.write_to(stream)
end

function mode_test_window(stream)
	new_window()
	.run(256, "0")
	.run(256, "1")
	.run(256, "2")
	.run(256, "3")
	.add_copy("\nc 16 255 > ", 16, 255)
	.add_copy("\nc 16 256+255 > ", 16, 256+255)
	.add_copy("\nc 16 256*2+255 > ", 16, 256*2+255)
	.add_copy("\nc 16 0 m0 > ", 16, 0, 0)  -- copy self
	.add_copy("\nc 16 16 m1 h >", 16, 16, 1) -- copy here
	.add_copy("\nc 16 0 m2 n0 >", 16, 0, 2)  -- copy near 0
	.add_copy("\nc 16 0 m3 n1 >", 16, 0, 3)  -- copy near 1	
	.add_copy("\nc 16 0 m4 n2 >", 16, 0, 4)  -- copy near 2	
	.add_copy("\nc 16 0 m5 n3 >", 16, 0, 5)  -- copy near 3
	.add_copy("\nc 16 255 m6 s0 >", 16, 255, 6)  -- copy same 0	
	.add_copy("\nc 16 255 m7 s1 >", 16, 255, 7)  -- copy same 1	
	.add_copy("\nc 16 255 m8 s2 >", 16, 255, 8)  -- copy same 2
	.write_to(stream)
end

function add_copy_mode_test_window(stream)
	new_window()
	.run(256, "0")
	.run(256, "1")
	.run(256, "2")
	.run(256, "3")
	.add("\n\nadd\tcopy")
	.add_copy("\nm0\t", 4, 0, 0)  -- copy self
	.add_copy("\nm1\t", 4, 127, 1)  -- copy here
	.add_copy("\nm2\t", 4, 0, 2)  -- copy near 0
	.add_copy("\nm3\t", 4, 0, 3)  -- copy near 1	
	.add_copy("\nm4\t", 4, 0, 4)  -- copy near 2	
	.add_copy("\nm5\t", 4, 0, 5)  -- copy near 3
	.add_copy("\nm6\t", 4, 255, 6)  -- copy same 0	
	.add_copy("\nm7\t", 4, 255, 7)  -- copy same 1	
	.add_copy("\nm8\t", 4, 255, 8)  -- copy same 2
	.add("\n\ncopy add\n")
	.copy_add(4, 0, 0, "\n")  -- copy self
	.copy_add(4, 127, 1, "\n")  -- copy here
	.copy_add(4, 0, 2, "\n")  -- copy near 0
	.copy_add(4, 0, 3, "\n")  -- copy near 1	
	.copy_add(4, 0, 4, "\n")  -- copy near 2	
	.copy_add(4, 0, 5, "\n")  -- copy near 3
	.copy_add(4, 255, 6, "\n")  -- copy same 0	
	.copy_add(4, 255, 7, "\n")  -- copy same 1	
	.copy_add(4, 255, 8, "\n")  -- copy same 2
	.write_to(stream)
end

--[[
address: 0       4                     15
         |       |                     |
source:  a b c d e f g h i j k l m n o p
target:  a b c d w x y z e f g h e f g h e f g h e f g h z z z z
         |               |
address: 16              24
		 
         COPY  4, 0
         ADD   4, w x y z
         COPY  4, 4
         COPY 12, 24
         RUN   4, z
--]]

function rfc_test_window(stream)
	new_window(16, 0)
	.copy(4,  0     )
	.add (    'wxyz')
	.copy(4,  4     )
	.copy(12, 24    )
	.run (4,  'z'   )
	.write_to(stream)
end

function main()
	local file = io.open("vcdiff.x", "wb")
	write_header(file)
	rfc_test_window(file)
	-- run_test_window(file)
	-- add_test_window(file)
	-- copy_test_window(file)
	-- mode_test_window(file)
	-- add_copy_mode_test_window(file)
end

main()