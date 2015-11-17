-record(counter, {type, 
                  value}).

-record(player, {id,
                 name,
                 password,
                 login_errors = 0,
                 disabled = false,
                 npc = false}).

-record(connection, {player,
                     process = none}).

-record(game, {perception,
               explored}).

-record(resource, {index, 
                   name,
                   max,
                   quantity}).

-record(resource_def, {tile,
                       name,
                       quantity}).

-record(poi_def, {tile,
                  name}).

-record(explored_map, {player,
                       tiles,
                       new_tiles}).

-record(event, {id, 
                player_process,
                type,
                data,
                source = none,
                tick}).

-record(perception, {entity,
                     data}).

-record(map, {index,
              tile,
              layers}).

-record(obj, {id,
              pos,
              player,
              class,
              subclass = none,
              name,
              state,
              effect = [],
              vision = false}).
            
-record(charge_time, {unit_id,
                      charge_time}).

-record(action, {source_id,
                 type,
                 data}).

-record(villager, {id,
                   task,
                   dwelling}).

-record(test, {attr,
               value}).

-record(htn, {label,
              index,
              parent,
              conditions = [],
              effects = [],
              type,
              task = none}).

-record(npc, {id,
              target = none,
              orders = guard,
              orders_data = {2,7},
              plan = [],
              new_plan = false,
              task_state = none,
              task_index = 0,
              path = none}).

-record(effect, {key,
                 type,
                 data}).

-record(combat, {id, 
                 attacks}).
