#===============================================================================
# * Pseudo-fixed EXP gain - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for RPG Maker XP. It change the way that your characters gain
# exp to a Pseudo-fixed system good for long games.
#
# All your character have the same EXP requirement for all levels and the
# values gained as EXP are changed according theirs current levels. The EXP
# defined in enemies database is used for determining the minimum level for
# changing these values.
#
# An example using the default values: All your actors need 100 EXP for 
# gaining each level. If you set an enemy EXP as 20, all your actors gain
# 12 EXP (the first value) for every time that this enemy is defeated during
# the levels 1-19. At level 20, your actors gain 10 EXP (the second value),
# at level 21 is 8 (the third value) ... and at level 27-Infinite your actors
# gain 1 EXP (the last value).
#
#===============================================================================
#
# To this script works, put it above main. 
# 
#===============================================================================

EXP_FOR_LEVEL_UP = 100 # All level requires this EXP quantity.

EXP_VALUES = [12,10,8,6,4,3,2,1] # The EXP values list. 0 still means no exp.

# When true and you battle versus two or more enemies, pick the average minimum
# level requirement (enemy EXP at database). When false, picks the lower value.
USE_ENEMY_AVERAGE_EXP=false

# When true, evey actor gains a different EXP based at each level. When false, 
# all gain the EXP based at highest party level.
INDIVIDUAL_EXP_GAIN=false

class Scene_Battle
  def start_phase5
    # Shift to phase 5
    @phase = 5
    # Play battle end ME
    $game_system.me_play($game_system.battle_end_me)
    # Return to BGM before battle started
    $game_system.bgm_play($game_temp.map_bgm)
    # Initialize amount of gold, and treasure
    gold = 0
    treasures = []
    levelExpLimit = 0
    validEnemyExp = 0.0
    # Loop
    for enemy in $game_troop.enemies
      # If enemy is not hidden
      unless enemy.hidden
        # Add amount of gold obtained
        gold += enemy.gold
        if USE_ENEMY_AVERAGE_EXP # Little change of EXP gain here
          if enemy.exp>0
            levelExpLimit+=enemy.exp
            validEnemyExp+=1.0
          end
        else  
          levelExpLimit = [levelExpLimit,enemy.exp].min
        end  
        # Determine if treasure appears
        if rand(100) < enemy.treasure_prob
          if enemy.item_id > 0
            treasures.push($data_items[enemy.item_id])
          end
          if enemy.weapon_id > 0
            treasures.push($data_weapons[enemy.weapon_id])
          end
          if enemy.armor_id > 0
            treasures.push($data_armors[enemy.armor_id])
          end
        end
      end
    end
    # Treasure is limited to a maximum of 6 items
    treasures = treasures[0..5]
    
    # Obtaining EXP. BIGGEST CHANGE HERE
    if USE_ENEMY_AVERAGE_EXP && levelExpLimit>0
      levelExpLimit=(levelExpLimit/validEnemyExp).floor
    end  
    expGained = [] # First calculates the EXP gained at this array
    for i in 0...$game_party.actors.size
      actor = $game_party.actors[i]
      exp=nil
      if actor.cant_get_exp? == false && levelExpLimit>0
        # If the enemy EXP is equal or bigger than player level, 
        # the game uses another value of the array
        expIndex = 0
        if levelExpLimit<=actor.level
          expIndex = actor.level-levelExpLimit+1
          expIndex = -1 if expIndex>=EXP_VALUES.size
        end
        exp = EXP_VALUES[expIndex]
      end
      expGained.push(exp)
    end
    expWindow = nil # EXP for Window
    if INDIVIDUAL_EXP_GAIN
      expWindow = expGained
    else  
      # Change all non-nil values to the lowest value
      lowerValue = expGained.compact.sort[0]
      expGained.map!{|value| lowerValue if value }
      expWindow = lowerValue
    end
    # Add the EXP
    for i in 0...$game_party.actors.size
      actor = $game_party.actors[i]
      if expGained[i] && expGained[i] > 0
        last_level = actor.level
        actor.exp += expGained[i]
        if actor.level > last_level
          @status_window.level_up(i)
        end
      end
    end
    
    # Obtaining gold
    $game_party.gain_gold(gold)
    # Obtaining treasure
    for item in treasures
      case item
      when RPG::Item
        $game_party.gain_item(item.id, 1)
      when RPG::Weapon
        $game_party.gain_weapon(item.id, 1)
      when RPG::Armor
        $game_party.gain_armor(item.id, 1)
      end
    end
    # Make battle result window
    @result_window = Window_BattleResult.new(expWindow, gold, treasures)
    # Set wait count
    @phase5_wait_count = 100
  end
end  
  
class Game_Actor < Game_Battler  
  def make_exp_list
    actor = $data_actors[@actor_id]
    @exp_list[1] = 0
    for i in 2..100
      @exp_list[i] = i > actor.final_level ? 0 : @exp_list[i-1]+EXP_FOR_LEVEL_UP
    end
  end
end

if INDIVIDUAL_EXP_GAIN
  class Window_BattleResult < Window_Base  
    def initialize(exp, gold, treasures)
      @exp = exp*"/" # Format EXP here
      @gold = gold
      @treasures = treasures
      super(160, 0, 320, @treasures.size * 32 + 64)
      self.contents = Bitmap.new(width - 32, height - 32)
      self.y = 160 - height / 2
      self.back_opacity = 160
      self.visible = false
      refresh
    end
  end
end