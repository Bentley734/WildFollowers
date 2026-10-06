return {
  {key="follower_sprite_set",label="Follower sprites",type="choice",default="untamed",
    choices={{"UNTAMED","untamed"},{"G9RP","g9rp"}}},
  {key="follower_trainer_spacing",label="Trainer spacing",type="choice",default=1,
    choices={{"1 PX",1},{"2 PX",2},{"3 PX",3},{"4 PX",4},{"5 PX",5},{"6 PX",6},{"7 PX",7}},
    description="Extra pixels of trail spacing between the trainer and first follower."},
  {key="follower_spacing",label="Follower spacing",type="choice",default=1,
    choices={{"1 PX",1},{"2 PX",2},{"3 PX",3},{"4 PX",4},{"5 PX",5},{"6 PX",6},{"7 PX",7}},
    description="Extra pixels of trail spacing between consecutive followers."},
  {key="follower_count",label="Follower count",type="choice",default=1,
    choices={{"0",0},{"1",1},{"2",2},{"3",3},{"4",4},{"5",5},{"6",6}},
    description="Number of healthy party Pokemon following the trainer."},
}
