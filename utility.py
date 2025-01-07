def modify_file(file_path, search_phrase, insert_text):
	# Read the file
	with open(file_path, 'r') as file:
		lines = file.readlines()

	# Modify lines containing the search_phrase
	modified_lines = []
	for line in lines:
		if search_phrase in line:
			line = line.rstrip() + insert_text + '\n'
		modified_lines.append(line)

	# Write the modified lines back to the file
	with open(file_path, 'w') as file:
		file.writelines(modified_lines)

file_path = "data/level12.json"
search_phrase = "queue_free"
insert_text = ",\n\t\t\t\t\t\t\"start_disabled\": false"

modify_file(file_path, search_phrase, insert_text)