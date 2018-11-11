--[[
         a b c d e f g h i j k l m n o p
         a b c d w x y z e f g h e f g h e f g h e f g h z z z z

         COPY  4, 0
         ADD   4, w x y z
         COPY  4, 4
         COPY 12, 24
         RUN   4, z
--]]

--[[--------------------------------------
	local file = io.open("vcdiff.x", "wb")
	write_header(file)
	new_window(16, 0)
	.copy(10, 0)
	.add('wxyz')
	.copy(4, 4)
	.copy(12,24)
	.run(4, 'z')
	.write_to(file)
	file:close()
--]]--------------------------------------

function varint(int)
	local bytes = {}
	table.insert(bytes, 1, (int & 127))
	int = int >> 7
	while int > 0 do
		table.insert(bytes, 1, (int & 127) | 128)
		int = int >> 7
	end
	return string.char(table.unpack(bytes))
end

function size_of_int(int)
	local size = 1
	while int > 127 do
		size = size + 1
		int = int >> 7
	end
	return size
end

function write_bytes(stream, ...)
	stream:write(string.char(...))
end

function write_ints(stream, ...)
	local bytes = {}
	local pos = 1
	local ints = {...}
	
	if #ints == 1 and ints[1] < 128 then
		write_bytes(stream, ints[1])
		return
	end
	
	for _, int in ipairs(ints) do
		table.insert(bytes, pos, (int & 127))
		int = int >> 7
		while int > 0 do
			table.insert(bytes, pos, (int & 127) | 128)
			int = int >> 7
		end
		pos = #bytes + 1
	end
	write_bytes(stream, table.unpack(bytes))
end

--[[
      Header
          Header1                                  - byte
          Header2                                  - byte
          Header3                                  - byte
          Header4                                  - byte
          Hdr_Indicator                            - byte
          [Secondary compressor ID]                - byte
          [Length of code table data]              - integer
          [Code table data]
              Size of near cache                   - byte
              Size of same cache                   - byte
              Compressed code table data
		  [Length of application header]           - integer
          [Application header]
		  
		  
Hdr_Indicator:
	  
       7 6 5 4 3 2 1 0
      +-+-+-+-+-+-+-+-+
      | | | | | | | | |
      +-+-+-+-+-+-+-+-+
                 ^ ^ ^
                 | | |
                 | | +-- VCD_DECOMPRESS
                 | +---- VCD_CODETABLE
				 +------ XD3_APPHEADER
				 
Secondary compressor ID:
  VCD_DJW_ID    = 1,
  VCD_LZMA_ID   = 2,
  VCD_FGK_ID    = 16  /* Note: these are not standard IANA-allocated IDs! */
]]

function write_header(stream, compressor_id, code_table, app_header)
	if not (compressor_id or code_table or app_header) then
				   --   1V  1C  1D ver0   0
		stream:write "\xD6\xC3\xC4\x00\x00"
	else
		stream:write "\xD6\xC3\xC4\x00"
		
		local header_indicator = (compressor_id and 1) or 0
		
		if code_table then 
			header_indicator = header_indicator | 2 
		end
		
		if app_header then 
			app_header = header_indicator | (1<<2) 
		end
		
		write_bytes(stream, header_indicator)
		
		if compressor_id then 
			write_ints(stream, compressor_id)
		end
		
		if code_table then 
			write_ints(stream, #code_table)
			stream:write(code_table)
		end
		
		if app_header then
			write_ints(stream, #app_header)
			stream:write(app_header)
		end
	end
	
end

--[[
      Win_Indicator                            - byte
      [Source segment length]                  - integer
      [Source segment position]                - integer
      The delta encoding of the target window

      Win_Indicator:
          This byte is a set of bits, as shown:

          7 6 5 4 3 2 1 0
         +-+-+-+-+-+-+-+-+
         | | | | | | | | |
         +-+-+-+-+-+-+-+-+
                    ^ ^ ^
                    | | |
                    | | +-- VCD_SOURCE
                    | +---- VCD_TARGET
				    +------ XD3_ADLER32
					  
]]

function write_window_header(stream, use_target, source_length, source_position, adler32)
	local window_indicator = (source_length and ((use_target and 2) or 1)) or 0
	if adler32 then
		window_indicator = window_indicator | (1<<2)
	end
	if source_length then
		write_bytes(stream, window_indicator)
		write_ints(stream, source_length, source_position or 0)
	else
		write_bytes(stream, 0)
	end
	
end

--[[
      Length of the delta encoding            - integer
      The delta encoding
          Length of the target window         - integer
          Delta_Indicator                     - byte
          Length of data for ADDs and RUNs    - integer
          Length of instructions section      - integer
          Length of addresses for COPYs       - integer
		  [adler32 checksum]                  - 4 bytes
          Data section for ADDs and RUNs      - array of bytes
          Instructions and sizes section      - array of bytes
          Addresses section for COPYs         - array of bytes

	   Delta_Indicator:
            This byte is a set of bits, as shown:

          7 6 5 4 3 2 1 0
         +-+-+-+-+-+-+-+-+
         | | | | | | | | |
         +-+-+-+-+-+-+-+-+
                    ^ ^ ^
                    | | |
                    | | +-- VCD_DATACOMP
                    | +---- VCD_INSTCOMP
                    +------ VCD_ADDRCOMP

              VCD_DATACOMP:   bit value 1.
              VCD_INSTCOMP:   bit value 2.
              VCD_ADDRCOMP:   bit value 4.
]]

function write_delta_header(stream, target_length, data_length, instructions_length, addresses_length, adler32)
	local delta_length = size_of_int(target_length) + 1 
		+ size_of_int(data_length) 
		+ size_of_int(instructions_length)
		+ size_of_int(addresses_length)
		+ data_length
		+ instructions_length
		+ addresses_length
		+ ((adler32 and 4) or 0)
	
	write_ints(stream, delta_length, target_length)
	write_bytes(stream, 0)
	write_ints(stream, data_length, instructions_length, addresses_length)
	
	if adler32 then
		stream:write(adler32) 
	end
end

function write_window(stream, target_size, data, instructions, addresses
	, source_length, source_position, use_target, adler32)
	if adler32 then
		assert(#adler32 == 4, "wrong size of adler32")
	end
	write_window_header(stream, use_target, source_length, source_position, adler32)
	write_delta_header(stream, target_size, #data, #instructions, #addresses, adler32)
	stream:write(data, instructions, addresses)
end


--[[
        TYPE      SIZE     MODE    TYPE     SIZE     MODE     INDEX
       ---------------------------------------------------------------
    1.  RUN         0        0     NOOP       0        0        0
    2.  ADD    0, [1,17]     0     NOOP       0        0      [1,18]
    3.  COPY   0, [4,18]     0     NOOP       0        0     [19,34]
    4.  COPY   0, [4,18]     1     NOOP       0        0     [35,50]
    5.  COPY   0, [4,18]     2     NOOP       0        0     [51,66]
    6.  COPY   0, [4,18]     3     NOOP       0        0     [67,82]
    7.  COPY   0, [4,18]     4     NOOP       0        0     [83,98]
    8.  COPY   0, [4,18]     5     NOOP       0        0     [99,114]
    9.  COPY   0, [4,18]     6     NOOP       0        0    [115,130]
   10.  COPY   0, [4,18]     7     NOOP       0        0    [131,146]
   11.  COPY   0, [4,18]     8     NOOP       0        0    [147,162]
   12.  ADD       [1,4]      0     COPY     [4,6]      0    [163,174]
   13.  ADD       [1,4]      0     COPY     [4,6]      1    [175,186]
   14.  ADD       [1,4]      0     COPY     [4,6]      2    [187,198]
   15.  ADD       [1,4]      0     COPY     [4,6]      3    [199,210]
   16.  ADD       [1,4]      0     COPY     [4,6]      4    [211,222]
   17.  ADD       [1,4]      0     COPY     [4,6]      5    [223,234]
   18.  ADD       [1,4]      0     COPY       4        6    [235,238]
   19.  ADD       [1,4]      0     COPY       4        7    [239,242]
   20.  ADD       [1,4]      0     COPY       4        8    [243,246]
   21.  COPY        4      [0,8]   ADD        1        0    [247,255]
       ---------------------------------------------------------------
]]

local RUN, ADD = 0, 1
local SAME_MODE_SART = 6
local COPY_MODE = { [0]= 19, 35, 51, 67, 83, 99, 115, 131, 147 }

local ADD_COPY_MODE = { [0]=
	163, 175, 187, 199, 211, 223, -- add size [1,4], copy size [4,6] mode [0,5]
	235, 239, 243                 -- add size [1,4], copy size 4 mode [6,8]
}

local COPY_ADD = 247 -- copy size 4 mode [0,8], add size 1

function set_address_mode(address, mode)
	mode = mode or 0
	
	if mode == 0 and address < 0 then
		mode = 1
		address = -address
	end
	
	assert(address >= 0)
	
	return address, mode
end

function new_window(source_length, source_position)
	local this = {}
	local target_size, data, instructions, addresses = 0, "", "", ""
	
	function this.write_to(stream)
		write_window(stream, target_size, data, instructions, addresses, source_length, source_position)
		return this
	end
	
	function this.add(part)
		target_size = target_size + #part
		data = data .. part
		if #part >= 1 and #part <= 17 then
			instructions = instructions .. string.char(ADD + #part)
		else
			instructions = instructions .. string.char(ADD) .. varint(#part)
		end
		return this
	end

	
	function this.copy(size, address, mode)
		address, mode = set_address_mode(address, mode)
		
		if size >= 4 and size <= 18 then
			instructions = instructions .. string.char(COPY_MODE[mode] + size - 3)
		else
			instructions = instructions .. string.char(COPY_MODE[mode]) .. varint(size)
		end
		
		if mode < SAME_MODE_SART then
			addresses = addresses .. varint(address)
		else
			addresses = addresses .. string.char(address)
		end
		
		target_size = target_size + size
		
		return this
	end
	
	function this.add_copy(part, size, address, mode)
		address, mode = set_address_mode(address, mode)
		
		if (mode >= SAME_MODE_SART and (size ~= 4)) 
		or (#part > 4 or #part < 1)
		or (size > 6 or size < 4)
		then
			this.add(part).copy(size, address, mode)
		else
			data = data .. part

			if mode >= SAME_MODE_SART then
				assert(size == 4)
				instructions = instructions .. string.char(ADD_COPY_MODE[mode] + #part - 1)
				addresses = addresses .. string.char(address)
			else
				instructions = instructions 
					.. string.char(ADD_COPY_MODE[mode] 
						+ (#part - 1)*3 + size - 4)
				addresses = addresses .. varint(address)
			end
			
			target_size = target_size + #part + size
		end
		
		return this
	end
	
	function this.copy_add(size, address, mode_part, part)
		local mode = 0
		
		if part then
			mode = mode_part or 0
		else
			part = mode_part
		end
		
		address, mode = set_address_mode(address, mode)
		
		if size == 4 and #part == 1 then
			data = data .. part
			instructions = instructions .. string.char(COPY_ADD + mode)
			if mode < SAME_MODE_SART then
				addresses = addresses .. varint(address)
			else
				addresses = addresses .. string.char(address)
			end
			
			target_size = target_size + size + #part
		else
			this.copy(size, address, mode).add(part)
		end
		
		return this
	end
	
	function this.run(count, part)
		if #part == 1 then
			data = data .. part
			instructions = instructions .. string.char(RUN) .. varint(count)
			target_size = target_size + count
		elseif count > 1 then
			this.add_copy(part, #part * (count - 1), -#part)
		elseif #part > 1 and count == 1 then
			this.add(part)
		end
		return this
	end
	
	return this
end