package game

ItemId :: enum {
	Empty = 0,
	Bomb,
	Sword = 100, // values 100 and greater are for weapons
}

ItemData :: struct {
	id:        ItemId,
	count:     int, // This can also be used as durability
	max_count: int,
}
