--Initialise Variables/Addresses
--Massive thanks to GhostShroom on the Red Earth Discord for Lua assistance
local int textx = 2
local int textx_Right = 240
local int texty = 10

--Each address is coupled with an additional WORD 4 bytes later
--local BG_Layer_Visible_Adr = 0x2051CAA --(3*0X10), Byte, blanking functionally disables the layer
local BG_Layer_Visible_Adr = 0xFF4473 --(3 Bytes), setting to 0x04 functionally disables the layer
--local BG_Layer_X_Pos_Adr = 0xFF4234 -- (3*0X04), WORDs
--local BG_Layer_Y_Pos_Adr = 0xFF4238 -- (3*0X04), WORDs
local BG_Layer_X_Pos_Adr = 0x0205E1E8 -- (3*0X04), WORDs
local BG_Layer_Y_Pos_Adr = BG_Layer_X_Pos_Adr + 0x08 -- (3*0X04), WORDs
local BG_Layer_X2_Pos_Adr = BG_Layer_X_Pos_Adr+4 -- (3*0X04), WORDs
local BG_Layer_Y2_Pos_Adr = BG_Layer_Y_Pos_Adr+4 -- (3*0X04), WORDs
local Sprite_Visibility_Flags_Adr = 0xFF4460 -- + 12 * 0x100
local Sprite_X_Pos_Adr = 0x0205ED7C --WORD
local Sprite_Y_Pos_Adr = Sprite_X_Pos_Adr + 0x02 --WORD
local Sprite_X2_Pos_Adr = 0x0206157C --WORD
local Sprite_Y2_Pos_Adr = Sprite_X2_Pos_Adr + 0x02 --WORD
local P1_Visibility_Flag_Adr = 0x0200D18D --Space = 0x400
local P1_X_Pos_Adr = 0x0200D1F0 --WORD
local P1_Y_Pos_Adr = 0x0200D1F4 --WORD

local Timer = {
	Adr = 0x0200EB33,
	Maxvalue = 0x9999,
--Character Select Timer
	CSSAdr = 0x02012CA9,
	CSSMaxvalue = 0x20,
}

--Tally Up stuff
--local Max_Layers = No_of_BG_Layers + No_of_Sprites + No_of_Players

--Arrays for later. These are what'll be updated
--Initial Values for both collection/proper reseting

--Vars to be updated after initialisation
--Array to place Unit Space. Example:
--Player 1s Unit ID = FF3000. There are 2 players,
--and Player 2s Unit ID begins at FF3400. In this case,
--the Unit Space is P2s Unit ID - P1s Unit ID, 0x400
local Unit_Space =
{
	Players = 0x3D8,
	Sprites = 0x14,
	--3S handles sprites like Second Impact, where there are 2 addresses that define where the thing is placed
	Sprites2 = 0x14,
	BG_Layers = 0x10
}
local Selection =
{
Mode = 1,
Layerno = 0
}
local Maximum =
{
BG_Layers = 5,
Sprites = 30,
Sprites2 = 1,
Players = 2
}

--Updated Vars for selection/Movement
local display_layer_info = 1
local infinite_time = 1
local Stage_ID = 0x020606E7
local current_stage = 0x00
local Write_to_Players = 0

--Vars to detect pressing Buttons for smooth movement
local Button_State = {
	None,
	Pressed,
	Held,
	Released	
}

local Input = {
	W = 0, --MOVEMENT KEYS
	A = 0,
	S = 0,
	D = 0,
	J = 0,-- TURN OFF LAYER
	L = 0, --Increment Layerno
	K = 0, --Decrement Layerno
	X = 0, --RESET CURRENT SELECTED ELEMENT POSITION
--	Z = 0, --RESET ALL ELEMTNS TO DEFAULT POSITIONS NOT IMPLEMENTED!
	C = 0,  --ENABLE/DISABLE INFINITE TIME
	V = 0,	--Togglew Write to PLayers
}	

local LayerZ = {}

	-- Initialise Offsets to whatever the game outputs
--INITIALISE BACKGROUND LAYER POSITIONS/VISIBILITY
--0-2 = Background Layer, 3-15 = Sprites, 16-17 = Players
	for i = 0,Maximum.BG_Layers-1,1 do-- (3*0X10), WORDs
		LayerZ[i] = {
			Initial = {
			X = memory.readword(BG_Layer_X_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y = memory.readword(BG_Layer_Y_Pos_Adr +(Unit_Space.BG_Layers*i)),
			X2 = memory.readword(BG_Layer_X2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y2 = memory.readword(BG_Layer_Y2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Visibility = memory.readbyte(BG_Layer_Visible_Adr +(i))
			},
			Offset  = {X = 0,
					   Y = 0
			},
			Current	    = {
			X = memory.readword(BG_Layer_X_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y = memory.readword(BG_Layer_Y_Pos_Adr +(Unit_Space.BG_Layers*i)),
			X2 = memory.readword(BG_Layer_X2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y2 = memory.readword(BG_Layer_Y2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Visibility = memory.readbyte(BG_Layer_Visible_Adr +(i))
			},
			Address		= {
			Vis = (BG_Layer_Visible_Adr +(i)),
			X = (BG_Layer_X_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y = (BG_Layer_Y_Pos_Adr +(Unit_Space.BG_Layers*i)),
			X2 = (BG_Layer_X2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			Y2 = (BG_Layer_Y2_Pos_Adr +(Unit_Space.BG_Layers*i)),
			}
		}
	end
	
	--INITIALISE SPRITES POSITIONS/VISIBILITY-- + 12 * 0x100
	for i = Maximum.BG_Layers, Maximum.BG_Layers + Maximum.Sprites - 1,1 do
		LayerZ[i] = {
			Initial = {
			X = memory.readword(Sprite_X_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Y = memory.readword(Sprite_Y_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			X2 = memory.readword(Sprite_X2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Y2 = memory.readword(Sprite_Y2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Visibility = memory.readbyte(Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			},
			Offset  = {X = 0,
					   Y = 0
			},
			Current	    = {
			X = memory.readword(Sprite_X_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Y = memory.readword(Sprite_Y_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			X2 = memory.readword(Sprite_X2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Y2 = memory.readword(Sprite_Y2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			Visibility = memory.readbyte(Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers))),
			},
			Address		= {
			Vis = Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers)),
			X = Sprite_X_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers)),
			Y = Sprite_Y_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers)),
			X2 = Sprite_X2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers)),
			Y2 = Sprite_Y2_Pos_Adr+(Unit_Space.Sprites*(i- Maximum.BG_Layers))
			}
		}
	end
	
	--INITIALISE SPRITES POSITIONS/VISIBILITY-- + 12 * 0x100
--3S' Sprites are offset differently after the 5th one. No idea why just roll with it
--The idea is to start where the last loop left off, and continue with the new Unit Space for the rest of the sprites
	for i = Maximum.BG_Layers + Maximum.Sprites, Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 - 1,1 do
		LayerZ[i] = {
			Initial = {
			X = memory.readword(Sprite_X_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Y = memory.readword(Sprite_Y_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			X2 = memory.readword(Sprite_X2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Y2 = memory.readword(Sprite_Y2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Visibility = memory.readbyte(Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers- Maximum.Sprites))),
			},
			Offset  = {X = 0,
					   Y = 0
			},
			Current	    = {
			X = memory.readword(Sprite_X_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Y = memory.readword(Sprite_Y_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			X2 = memory.readword(Sprite_X2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Y2 = memory.readword(Sprite_Y2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites))),
			Visibility = memory.readbyte(Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers- Maximum.Sprites))),
			},
			Address		= {
			Vis = Sprite_Visibility_Flags_Adr + (Unit_Space.Sprites*(i- Maximum.BG_Layers - Maximum.Sprites)),
			X = Sprite_X_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites)),
			Y = Sprite_Y_Pos_Adr - 0x11 + (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites)),
			X2 = Sprite_X2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites)),
			Y2 = Sprite_Y2_Pos_Adr - 0x11+ (Unit_Space.Sprites * Maximum.Sprites-1) + Unit_Space.Sprites2 + (Unit_Space.Sprites*(i - Maximum.BG_Layers - Maximum.Sprites)),
			}
		}
	end
	
	--INITIALISE PLAYERS POSITIONS/VISIBILITY
	--0-2 = Background Layer, 3-15 = Sprites, 16-17 = Players
	for i = Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2, Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 + Maximum.Players-1,1 do
		LayerZ[i] = {
			Initial = {
			X = memory.readword(P1_X_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2))),
			Y = memory.readword(P1_Y_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2))),
			Visibility = memory.readbyte(P1_Visibility_Flag_Adr + (Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites- Maximum.Sprites2))),
			},
			Offset  = {X = 0,
					   Y = 0
			},
			Current	    = {
			X = memory.readword(P1_X_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2))),
			Y = memory.readword(P1_Y_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2))),
			Visibility = memory.readbyte(P1_Visibility_Flag_Adr + (Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites- Maximum.Sprites2)))
			},
			Address		= {
			Vis = P1_Visibility_Flag_Adr + (Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2)),		
			X = P1_X_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2)),			
			Y = P1_Y_Pos_Adr +(Unit_Space.Players*(i - Maximum.BG_Layers - Maximum.Sprites - Maximum.Sprites2))		,	
		}
	}
	end
	
	while true do
--Actual Memory overwrite. Maintain adjustments even if not on the layer
	local keys = input.get()

	--UPDATE PLAYERS POSITIONS/VISIBILITY FOR DISPLAY
--		gui.text(textx,0,"---CURRENT---")
		gui.text(textx,0,string.format("Layerno = %d", Selection.Layerno))
		gui.text(textx,10,string.format("Vis = %d", LayerZ[Selection.Layerno].Current.Visibility))	
		gui.text(textx,20,string.format("X = %x", LayerZ[Selection.Layerno].Current.X))	
		gui.text(textx,30,string.format("Y = %x", LayerZ[Selection.Layerno].Current.Y))	
		gui.text(textx,40,string.format("Address X = %x", LayerZ[Selection.Layerno].Address.X))	
		gui.text(textx,60,string.format("Address Y = %x", LayerZ[Selection.Layerno].Address.Y))	
		--UPDATE POSITIONS/VISIBILITY IN MEMORY
--Display Secondary Position 
	if Selection.Layerno < (Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2)  then
		gui.text(textx,50,string.format("Address X2 = %x", LayerZ[Selection.Layerno].Address.X2))	
		gui.text(textx,70,string.format("Address Y2 = %x", LayerZ[Selection.Layerno].Address.Y2))	
	end

		gui.text(textx+140,texty*20, "C - Infinite Time = ".. infinite_time)
		gui.text(textx+140,texty*20+8, "V - Write_to_Players = ".. Write_to_Players)		

		--Move Right
		if Input.D == 0 and keys.D then
			if Selection.Mode == 1 then --If not on Background Layers
				LayerZ[Selection.Layerno].Offset.X = LayerZ[Selection.Layerno].Offset.X + 1
			else
				LayerZ[Selection.Layerno].Offset.X = LayerZ[Selection.Layerno].Offset.X - 1		
			end
		end

		--Move Left
		if Input.A == 0 and keys.A then
			if Selection.Mode == 1 then --If not on Background Layers
				LayerZ[Selection.Layerno].Offset.X = LayerZ[Selection.Layerno].Offset.X - 1
			else
				LayerZ[Selection.Layerno].Offset.X = LayerZ[Selection.Layerno].Offset.X + 1
			end
		end
		--Move Up	
		if Input.W == 0 and keys.W then
			if Selection.Mode == 1 then --If not on Background Layers
				LayerZ[Selection.Layerno].Offset.Y = LayerZ[Selection.Layerno].Offset.Y + 1
			else
				LayerZ[Selection.Layerno].Offset.Y = LayerZ[Selection.Layerno].Offset.Y - 1
			end
		end
		
		--Move Down
		if Input.S == 0 and keys.S then
			if Selection.Mode == 1 then --If not on Background Layers
				LayerZ[Selection.Layerno].Offset.Y = LayerZ[Selection.Layerno].Offset.Y - 1
			else
				LayerZ[Selection.Layerno].Offset.Y = LayerZ[Selection.Layerno].Offset.Y + 1
			end
		end	

			--Reset Position
		if Input.X == 0 and keys.X then
				LayerZ[Selection.Layerno].Offset.X = 0
				LayerZ[Selection.Layerno].Offset.Y = 0
				LayerZ[Selection.Layerno].Current.X = LayerZ[Selection.Layerno].Initial.X
				LayerZ[Selection.Layerno].Current.Y = LayerZ[Selection.Layerno].Initial.Y
				Input.X = 1
		end
		if Input.X == 1 and not keys.X then
			Input.X = 0
		end			
		
		--Increment current Layerno
		if Input.L == 0 and keys.L then
			if Selection.Layerno < (Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 + Maximum.Players -1)  then
				Selection.Layerno = Selection.Layerno + 1
				Input.L = 1
			else
				Selection.Layerno = 0
				Input.L = 1
			end
		end
		if Input.L == 1 and not keys.L then
			Input.L = 0
		end		
		
				--Decrement current Layerno
		if Input.K == 0 and keys.K then
			if Selection.Layerno > 0 then
				Selection.Layerno = Selection.Layerno - 1
				Input.K = 1
			else
				Selection.Layerno = (Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 + Maximum.Players -1)
				Input.K = 1
			end
		end
		if Input.K == 1 and not keys.K then
			Input.K = 0
		end		
		
			--Disable/Enable Layer visibility
		if Input.J == 0 and keys.J then
			if LayerZ[Selection.Layerno].Current.Visibility == 0 then
			--If not visible, reset Sprite/Player visibility, if BG Mode isn't 1, set BG visibility
				if Selection.Layerno == 0 then
					LayerZ[Selection.Layerno].Current.Visibility = 0x0E
					Input.J = 1
				else
					if Selection.Layerno == 1 then
						LayerZ[Selection.Layerno].Current.Visibility = 0x06
						Input.J = 1
					else
						if Selection.Layerno == 2 then
							LayerZ[Selection.Layerno].Current.Visibility = 206
							Input.J = 1
						else
							if Selection.Layerno > 2 then
								LayerZ[Selection.Layerno].Current.Visibility = 1
								Input.J = 1
							end
						end
					end
				end
				else
				LayerZ[Selection.Layerno].Current.Visibility = 0
				Input.J = 1
			end
		end
		if Input.J == 1 and not keys.J then
			Input.J = 0
		end		

--Unlike my other scripts, 3S handles sprites with 2 addresses for Pos, so each type needs it's own loop
--to individually update
	--UPDATE BGLAYERS
	for i = 0, Maximum.BG_Layers-1, 1 do
		--UPDATE LAYERS POSITIONS/VISIBILITY IN MEMORY
	--Position
			LayerZ[i].Current.X = LayerZ[i].Initial.X + LayerZ[i].Offset.X
			LayerZ[i].Current.Y = LayerZ[i].Initial.Y + LayerZ[i].Offset.Y					
			LayerZ[i].Current.X2 = LayerZ[i].Initial.X2 + LayerZ[i].Offset.X
			LayerZ[i].Current.Y2 = LayerZ[i].Initial.Y2 + LayerZ[i].Offset.Y	
			memory.writeword(LayerZ[i].Address.X,LayerZ[i].Current.X)
			memory.writeword(LayerZ[i].Address.Y,LayerZ[i].Current.Y)
			memory.writeword(LayerZ[i].Address.X2,LayerZ[i].Current.X2)
			memory.writeword(LayerZ[i].Address.Y2,LayerZ[i].Current.Y2)
	--Visibility
			memory.writebyte(LayerZ[i].Address.Vis,LayerZ[i].Current.Visibility)
--			memory.writebyte(LayerZ[i].Address.Vis,0x00)
	end
	--UPDATE SPRITES
	for i = Maximum.BG_Layers, Maximum.BG_Layers + Maximum.Sprites-1, 1 do
		--UPDATE LAYERS POSITIONS/VISIBILITY IN MEMORY
	--Position
			LayerZ[i].Current.X = LayerZ[i].Initial.X + LayerZ[i].Offset.X
			LayerZ[i].Current.Y = LayerZ[i].Initial.Y + LayerZ[i].Offset.Y					
			LayerZ[i].Current.X2 = LayerZ[i].Initial.X2 + LayerZ[i].Offset.X
			LayerZ[i].Current.Y2 = LayerZ[i].Initial.Y2 + LayerZ[i].Offset.Y	
			memory.writeword(LayerZ[i].Address.X,LayerZ[i].Current.X)
			memory.writeword(LayerZ[i].Address.Y,LayerZ[i].Current.Y)
			memory.writeword(LayerZ[i].Address.X2,LayerZ[i].Current.X2)
			memory.writeword(LayerZ[i].Address.Y2,LayerZ[i].Current.Y2)
	--Visibility
			memory.writebyte(LayerZ[i].Address.Vis,LayerZ[i].Current.Visibility)
--			memory.writebyte(LayerZ[i].Address.Vis,0x00)
	end

	for i = Maximum.BG_Layers + Maximum.Sprites, Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 - 1,1 do
		--UPDATE LAYERS POSITIONS/VISIBILITY IN MEMORY
	--Position
			LayerZ[i].Current.X = LayerZ[i].Initial.X + LayerZ[i].Offset.X
			LayerZ[i].Current.Y = LayerZ[i].Initial.Y + LayerZ[i].Offset.Y					
			LayerZ[i].Current.X2 = LayerZ[i].Initial.X2 + LayerZ[i].Offset.X
			LayerZ[i].Current.Y2 = LayerZ[i].Initial.Y2 + LayerZ[i].Offset.Y	
			memory.writeword(LayerZ[i].Address.X,LayerZ[i].Current.X)
			memory.writeword(LayerZ[i].Address.Y,LayerZ[i].Current.Y)
			memory.writeword(LayerZ[i].Address.X2,LayerZ[i].Current.X2)
			memory.writeword(LayerZ[i].Address.Y2,LayerZ[i].Current.Y2)
	--Visibility
			memory.writebyte(LayerZ[i].Address.Vis,LayerZ[i].Current.Visibility)
--			memory.writebyte(LayerZ[i].Address.Vis,0x00)
	end

if 	Write_to_Players == 1 then
	--UPDATE PLAYERS
	for i = Maximum.BG_Layers + Maximum.Sprites+ Maximum.Sprites2, Maximum.BG_Layers + Maximum.Sprites + Maximum.Sprites2 +  Maximum.Players-1, 1 do
		--UPDATE LAYERS POSITIONS/VISIBILITY IN MEMORY
	--Position
			LayerZ[i].Current.X = LayerZ[i].Initial.X + LayerZ[i].Offset.X
			LayerZ[i].Current.Y = LayerZ[i].Initial.Y + LayerZ[i].Offset.Y		
			memory.writeword(LayerZ[i].Address.X,LayerZ[i].Current.X)
			memory.writeword(LayerZ[i].Address.Y,LayerZ[i].Current.Y)
	--Visibility
			memory.writebyte(LayerZ[i].Address.Vis,LayerZ[i].Current.Visibility)
--			memory.writebyte(LayerZ[i].Address.Vis,0x00)
	end
end	
	--Infinite Time Toggle
	if keys.C and Input.C == 0 then
		if infinite_time == 1 then
			infinite_time = 0
			Input.C = 1
		else
			infinite_time = 1
			Input.C = 1
	end
end

	--Write to players
	if keys.V and Input.V == 0 then
		if Write_to_Players == 1 then
			Write_to_Players = 0
			Input.V = 1
		else
			Write_to_Players = 1
			Input.V = 1
	end
end
	
	if infinite_time == 1 then
		memory.writeword(Timer.Adr, Timer.Maxvalue)
		--Character Select
		memory.writeword(Timer.CSSAdr, Timer.CSSMaxvalue)
	end
	if not keys.C and Input.C == 1 then
		Input.C = 0	
	end

	emu.frameadvance()
end