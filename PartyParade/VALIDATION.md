# Party Parade 3.0.0 validation

All 3,315,069 selected headless assertions pass using Lua 5.3. All add-on Lua source compiles and Gen1Recomp 0.3.54 manifest validation passes.

Real supplied Untamed Advanced beta.7 source and add-on entry points run in the engine's actual mod sandbox. Engine services are mocked. Integration covers missing dependency rejection, unchanged native wild pool/controller/options, six independent follower slots, counts 0-6, safe initial arrival, draw scoping, native/manager option edits, menu-only ticks, prevention of double ticks, and shared preferences across game/new-option changes.

Other suites cover entry dialogue/doorway placement (1,250 checks), spacing, idle collisions, return routing, jump/mixed/random/wave/social/dance controllers, flower clipping and native paged-atlas pulse scaling.

Live visual gameplay and LOVE GPU rendering remain unverified. Install the release ZIP with enabled Untamed Advanced beta.7; smoke-test OPTION → PARTY PARADE, count 6, idle modes, menus, entry doors/stairs and switching to Emerald before relying on a long play session.

Reproduce with Python 3, lupa (Lua 5.3), extracted gen1recomp-0.3.54 and untamed_advanced folders alongside PartyParade, then run `python run_party_parade_tests.py`.
