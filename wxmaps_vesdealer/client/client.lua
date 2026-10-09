local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1, L9_1
L0_1 = {}
L1_1 = {}
L1_1.model = "baller"
L1_1.x = -952.21
L1_1.y = -1175.95
L1_1.z = 4.95
L1_1.heading = 287.98
L2_1 = {}
L2_1.model = "xls"
L2_1.x = -950.82
L2_1.y = -1178.67
L2_1.z = 4.95
L2_1.heading = 311.43
L3_1 = {}
L3_1.model = "toros"
L3_1.x = -940.0
L3_1.y = -1186.0
L3_1.z = 4.95
L3_1.heading = 62.65
L4_1 = {}
L4_1.model = "t20"
L4_1.x = -936.0
L4_1.y = -1184.0
L4_1.z = 4.95
L4_1.heading = 62.85
L5_1 = {}
L5_1.model = "nero"
L5_1.x = -933.0
L5_1.y = -1182.0
L5_1.z = 4.95
L5_1.heading = 62.85
L6_1 = {}
L6_1.model = "comet2"
L6_1.x = -931.0
L6_1.y = -1171.0
L6_1.z = 4.95
L6_1.heading = 170.69
L7_1 = {}
L7_1.model = "specter"
L7_1.x = -928.05
L7_1.y = -1170.33
L7_1.z = 4.95
L7_1.heading = 165.19
L0_1[1] = L1_1
L0_1[2] = L2_1
L0_1[3] = L3_1
L0_1[4] = L4_1
L0_1[5] = L5_1
L0_1[6] = L6_1
L0_1[7] = L7_1
L1_1 = {}
function L2_1(A0_2)
  local L1_2, L2_2, L3_2
  L1_2 = RequestModel
  L2_2 = A0_2
  L1_2(L2_2)
  L1_2 = 5000
  while true do
    L2_2 = HasModelLoaded
    L3_2 = A0_2
    L2_2 = L2_2(L3_2)
    if not (not L2_2 and L1_2 > 0) then
      break
    end
    L2_2 = Wait
    L3_2 = 100
    L2_2(L3_2)
    L1_2 = L1_2 - 100
  end
  L2_2 = HasModelLoaded
  L3_2 = A0_2
  return L2_2(L3_2)
end
function L3_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  L1_2 = math
  L1_2 = L1_2.random
  L2_2 = 0
  L3_2 = 159
  L1_2 = L1_2(L2_2, L3_2)
  L2_2 = math
  L2_2 = L2_2.random
  L3_2 = 0
  L4_2 = 159
  L2_2 = L2_2(L3_2, L4_2)
  L3_2 = SetVehicleColours
  L4_2 = A0_2
  L5_2 = L1_2
  L6_2 = L2_2
  L3_2(L4_2, L5_2, L6_2)
end
function L4_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L0_2 = print
  L1_2 = "Deleting spawned vehicles..."
  L0_2(L1_2)
  L0_2 = ipairs
  L1_2 = L1_1
  L0_2, L1_2, L2_2, L3_2 = L0_2(L1_2)
  for L4_2, L5_2 in L0_2, L1_2, L2_2, L3_2 do
    L6_2 = DoesEntityExist
    L7_2 = L5_2
    L6_2 = L6_2(L7_2)
    if L6_2 then
      L6_2 = DeleteEntity
      L7_2 = L5_2
      L6_2(L7_2)
      L6_2 = print
      L7_2 = "Deleted vehicle: "
      L8_2 = L5_2
      L7_2 = L7_2 .. L8_2
      L6_2(L7_2)
    end
  end
  L0_2 = {}
  L1_1 = L0_2
end
function L5_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  L1_2 = GetHashKey
  L2_2 = A0_2.model
  L1_2 = L1_2(L2_2)
  L2_2 = L2_1
  L3_2 = L1_2
  L2_2 = L2_2(L3_2)
  if not L2_2 then
    L2_2 = print
    L3_2 = "^1Failed to load model: "
    L4_2 = A0_2.model
    L3_2 = L3_2 .. L4_2
    L2_2(L3_2)
    return
  end
  L2_2 = CreateVehicle
  L3_2 = L1_2
  L4_2 = A0_2.x
  L5_2 = A0_2.y
  L6_2 = A0_2.z
  L7_2 = A0_2.heading
  L8_2 = true
  L9_2 = false
  L2_2 = L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
  L3_2 = L3_1
  L4_2 = L2_2
  L3_2(L4_2)
  L3_2 = table
  L3_2 = L3_2.insert
  L4_2 = L1_1
  L5_2 = L2_2
  L3_2(L4_2, L5_2)
  L3_2 = print
  L4_2 = "Spawned vehicle: "
  L5_2 = L2_2
  L4_2 = L4_2 .. L5_2
  L3_2(L4_2)
end
L6_1 = RegisterCommand
L7_1 = "spawncardealer"
function L8_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  L0_2 = L4_1
  L0_2()
  L0_2 = ipairs
  L1_2 = L0_1
  L0_2, L1_2, L2_2, L3_2 = L0_2(L1_2)
  for L4_2, L5_2 in L0_2, L1_2, L2_2, L3_2 do
    L6_2 = L5_1
    L7_2 = L5_2
    L6_2(L7_2)
  end
end
L9_1 = false
L6_1(L7_1, L8_1, L9_1)
L6_1 = RegisterCommand
L7_1 = "deletecardealer"
function L8_1()
  local L0_2, L1_2
  L0_2 = L4_1
  L0_2()
end
L9_1 = false
L6_1(L7_1, L8_1, L9_1)
