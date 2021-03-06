%% Author: Peter
%% Created: Sept 10, 2015
%% Description: Hierarchical Task Network for NPC AI
-module(htn).
-export([new/1,
         add_select_one/4,
         add_select_all/4,
         add_primitive/5,
         add_goto/5]).
-export([load/0, plan/3]).

-include("schema.hrl").

load() ->
    wander(),
    guard(),
    villager().

wander() ->
    new(wander),
    add_select_one(attack_enemy, wander, [target_visible], []),
    add_select_all(do_attack, attack_enemy, [], []),
    add_primitive(move_to_target, do_attack, [], [], move_to_target),
    add_primitive(melee_attack, do_attack, [], [], melee_attack),
    add_select_all(do_wander, wander, [], []),
    add_primitive(move_random_pos, do_wander, [], [], move_random_pos).

guard() ->
    new(guard),
    add_select_one(attack_enemy, guard, [target_visible], []),
    add_select_all(return_to_guard, attack_enemy, [max_guard_dist], []),
    add_primitive(move_guard_pos1, return_to_guard, [], [], move_guard_pos),
    add_select_all(do_attack, attack_enemy, [], []),
    add_primitive(move_to_target, do_attack, [], [], move_to_target),
    add_primitive(melee_attack, do_attack, [], [], melee_attack),
    add_select_all(do_guard, guard, [], []),
    add_primitive(move_guard_pos2, do_guard, [], [], move_guard_pos).

villager() ->
    new(villager),
    add_select_one(nearby_enemy, villager, [enemy_visible], []),
        add_select_all(flee_to_shelter, nearby_enemy, [has_shelter], []),
            add_primitive(set_pos_shelter, flee_to_shelter, [], [], set_pos_shelter),
            add_primitive(move_to_shelter, flee_to_shelter, [], [], move_to_pos),
        add_select_all(flee_to_hero, nearby_enemy, [hero_nearby], []),
            add_primitive(set_pos_hero, flee_to_hero, [], [], set_pos_hero),
            add_primitive(move_to_hero, flee_to_hero, [], [], move_to_pos),
        add_select_all(flee_randomly, nearby_enemy, [], []),
            add_primitive(move_randomly, flee_randomly, [], [], move_randomly),
    add_select_one(process_follow, villager, [morale_normal, has_order_follow], []),
        add_select_all(do_follow, process_follow, [], []),
            add_primitive(set_pos_hero, do_follow, [], [], set_pos_hero),
            add_primitive(move_to_hero, do_follow, [], [], move_to_pos),
    add_select_one(process_dwelling, villager, [morale_normal, shelter_needed, free_shelter], []),
        add_select_all(dwelling, process_dwelling, [], []),
            add_primitive(find_dwelling, dwelling, [], [], find_shelter),
            add_primitive(move_to_dwelling, dwelling, [], [], move_to_pos),
    add_select_one(process_harvester, villager, [morale_normal, assigned_harvester], []),
        add_select_all(process_harvest, process_harvester, [not_hauling, structure_not_full], []),
            add_primitive(set_pos_structure, process_harvest, [], [], set_pos_structure),
            add_primitive(move_to_structure, process_harvest, [], [], move_to_pos),
            add_primitive(do_harvest, process_harvest, [], [], harvest),
        add_select_all(process_storage, process_harvester, [storage_needed, free_storage], []),
            add_primitive(find_storage, process_storage, [], [], find_storage),
        add_select_all(process_haul, process_harvester, [has_storage], []),
            add_primitive(set_activity, process_haul, [], [], set_hauling),
            add_primitive(set_pos_structure, process_haul, [], [], set_pos_structure),
            add_primitive(move_to_structure, process_haul, [], [], move_to_pos),
            add_primitive(transfer_item, process_haul, [], [], load_resources),
            add_primitive(set_pos_storage, process_haul, [], [], set_pos_storage),
            add_primitive(move_to_storage, process_haul, [], [], move_to_pos),
            add_primitive(transfer_item, process_haul, [], [], unload_resources),            
            add_primitive(set_activity, process_haul, [], [], set_none),
        add_select_all(harvest_idle, process_harvester, [], []),
            add_primitive(idle, harvest_idle, [], [], idle),
    add_select_one(process_craft, villager, [morale_normal, assigned_craft], []),
        add_select_all(refine, process_craft, [has_order_refine], []),
            add_primitive(set_pos_structure, refine, [], [], set_pos_structure),
            add_primitive(move_to_structure, refine, [], [], move_to_pos),
            add_primitive(do_refine, refine, [], [], refine),
        add_select_all(craft, process_craft, [has_order_craft], []),
            add_primitive(set_pos_structure, craft, [], [], set_pos_structure),
            add_primitive(move_to_structure, craft, [], [], move_to_pos),
            add_primitive(do_craft, craft, [], [], craft),
        add_select_all(experiment, process_craft, [has_order_experiment], []),
            add_primitive(set_pos_structure, experiment, [], [], set_pos_structure),
            add_primitive(move_to_structure, experiment, [], [], move_to_pos),
            add_primitive(do_experiment, experiment, [], [], experiment),
        add_select_all(craft_idle, process_craft, [], []),
            add_primitive(idle, craft_idle, [], [], idle),
    add_select_one(process_idle, villager, [morale_normal], []),
        add_select_all(do_idle, process_idle, [], []),
            add_primitive(idle, do_idle, [], [], idle),
    add_select_one(process_forage, villager, [morale_low], []),
        add_primitive(do_forage, process_forage, [], [], do_forage),
    add_select_one(process_abandon, villager, [morale_very_low], []),
        add_primitive(do_abandon, process_abandon, [], [], do_abandon).

plan(PlanName, Id, Module) ->
    [Parent] = db:dirty_read(htn, {PlanName, PlanName}),
    Children = db:dirty_index_read(htn, {PlanName, PlanName}, #htn.parent),
    SortedChildren = lists:keysort(#htn.index, Children),

    put(plan_module, Module),

    erase(plan),
    
    process_child(SortedChildren, Parent#htn.type, Id),

    Plan = get(plan),
    Plan.

process_child([], primitive_task, _NPC) ->
    done;
process_child(Children, select_one, NPC) ->
    NextChild = process_child_selectone(Children, {false, none}, NPC),
    add_to_plan(NextChild),

    NextChildren = db:dirty_index_read(htn, NextChild#htn.label, #htn.parent),
    SortedChildren = lists:keysort(#htn.index, NextChildren),
    process_child(SortedChildren, NextChild#htn.type, NPC);

process_child(Children, select_all, NPC) ->
    Result = process_child_selectall(Children, true, NPC),
    
    case Result of
        true ->
            add_to_plan(Children);
        false ->
            nothing
    end.

process_child_selectone(_Children, {true, Child}, _NPC) ->
    Child;
process_child_selectone([Child | Rest], _Result, NPC) ->
    Conditions = Child#htn.conditions,
    lager:debug("Conditions: ~p", [Conditions]),
    NewResult = eval(Conditions, NPC),
    process_child_selectone(Rest, {NewResult, Child}, NPC).

process_child_selectall([], Result, _NPC) ->
    Result;
process_child_selectall([Child | Rest], _Result, NPC) ->
    Conditions = Child#htn.conditions,
    NewResult = eval(Conditions, NPC),

    process_child_selectall(Rest, NewResult, NPC).

eval(Conditions, NPC) ->
    eval(Conditions, true, NPC).
eval(_Conditions, false, _NPC) ->
    false;
eval([], Result, _NPC) ->
    Result;
eval([Condition | Rest], Result, NPC) ->
    lager:debug("Condition: ~p", [Condition]),
    Module = get(plan_module),
    NewResult = erlang:apply(Module, Condition, [NPC]),
    eval(Rest, Result and NewResult, NPC).

add_to_plan(Children) when is_list(Children) ->
    F = fun(Child) ->
            add_to_plan(Child)
        end,

    lists:foreach(F, Children);
add_to_plan(#htn{task = Task, type = Type}) when Type =:= primitive ->
    Plan = get_plan(get(plan)),    
    put(plan, Plan ++ [Task]);
add_to_plan(_) ->
    nothing.

get_plan(Plan) when is_list(Plan) ->
    Plan;
get_plan(_) ->
    [].

new(Label) ->
    put(plan_name, Label),
    put(primitive, 0),
    Htn = #htn{label = {Label, Label}, index = 0, type = select_one},
    db:dirty_write(Htn).

add_select_one(Label, Parent, Conditions, Effects) ->
    write(Label, Parent, Conditions, Effects, select_one, none).
add_select_all(Label, Parent, Conditions, Effects) ->
    write(Label, Parent, Conditions, Effects, select_all, none).
add_primitive(_Label, Parent, Conditions, Effects, Task) ->
    %Make primitive label unique as it is not used
    Num = get(primitive) + 1,
    put(primitive, Num),    
    write(Num, Parent, Conditions, Effects, primitive, Task).
add_goto(Label, Parent, Conditions, Effects, GotoTask) ->
    write(Label, Parent, Conditions, Effects, goto, GotoTask).

write(Label, Parent, Conditions, Effects, Type, Task) ->
    PlanName = get(plan_name),
    Children = db:dirty_index_read(htn, {PlanName, Parent}, #htn.parent),

    Htn = #htn{label = {PlanName, Label}, 
               index = length(Children),
               parent = {PlanName, Parent},
               conditions = Conditions,
               effects = Effects,
               type = Type,
               task = Task},

    db:dirty_write(Htn).
