local SIM = ...
print("scripts:", SIM.loadProject())
SIM.start()
local p = SIM.addPlayer(101, "Tester")
SIM.advance(1)
SIM.assertNoErrors("smoke")
print("OK smoke")
