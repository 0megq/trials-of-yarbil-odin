package game

ItemId :: enum {
	Empty = 0,
	Bomb,
	// Apple,
	// Rock,
	Sword = 100, // values 100 and greater are for weapons
	// Stick,
}

ItemData :: struct {
	id:        ItemId,
	count:     int, // This can also be used as durability
	max_count: int,
}

is_weapon :: proc(id: ItemId) -> bool {
	return id >= .Sword
}
