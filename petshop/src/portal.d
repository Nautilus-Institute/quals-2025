// This program implements a "Global Printing Service" that prints messages about pets.
// It has a memory corruption vulnerability that can be exploited to hijack the control flow.

import std.stdio;
import std.ascii;
import std.conv;
import std.string;
import std.socket;
import std.bitmanip;
import std.algorithm;
import std.file;
import std.process;
import std.digest.md;

import printer;
import bitmap;


pragma(inline, true)
bool is_valid_nickname(string nick_name) {
    if (nick_name.length < 0 || nick_name.length >= 32) {
        return false;
    }

    foreach (char c; nick_name) {
        if (!c.isAlpha && !c.isDigit && c != '_' && c != '-' && c != ' ') {
            return false;
        }
    }

    return true;
}
pragma(inline, false)


enum MenuChoice
{
    RegisterPet,
    ListPets,
    DelistPets,
    UpdatePetDescription,
    PrintPet,
    RegisterPrinter,
    ListPrinters,
    DeletePrinter,
    Exit,
    PrintSecondFlag = 199991
}

enum PetSpecies
{
    Dog = 1,
    Cat,
    Bird,
    Fish,
    Whale,
    Other
}

const int MAX_DESCRIPTION_CHARS = 512;

class Pet
{
    string nick_name;
    PetSpecies species;
    string breed;
    string color;
    string description;
    int image_width;
    int image_height;
    string image_path;
    bool description_in_file;
    bool delisted;

    this(string nick_name, PetSpecies species, string breed, string color, string description)
    {
        this.nick_name = nick_name;
        this.species = species;
        this.breed = breed;
        this.color = color;
        this.description = description;
        this.description_in_file = false;
        this.delisted = false;
        this.image_width = 0;
        this.image_height = 0;
        this.image_path = "";

        save_description();
    }

    void save_description()
    {
        if (description.length > MAX_DESCRIPTION_CHARS) {
            // we don't want to save everything in memory; let's save it to the file system

            // ensure the description directory exists
            if (!exists("description")) {
                mkdir("description");
            }

            string filename = "description/" ~ this.nick_name;
            auto file = File(filename, "w");
            file.write(description);
            file.close();
            description = "";
            description_in_file = true;
        }
        else {
            description_in_file = false;
        }
    }

    bool is_delisted()
    {
        return delisted;
    }

    bool delist()
    {
        delisted = true;
        return true;
    }

    bool is_description_in_file()
    {
        return description_in_file;
    }

    string get_description(int max_length = 0)
    {
        if (description_in_file) {
            string filename = "description/" ~ this.nick_name;
            if (!exists(filename) || !isFile(filename)) {
                return "Internal error:The description file does not exist.";
            }
            auto file = File(filename, "r");
            auto buf = file.rawRead(new ubyte[file.size()]);
            string content = cast(string)buf;
            file.close();

            // truncation
            if (max_length > 0 && content.length > max_length) {
                content = content[0 .. max_length] ~ "...";
            }

            // if the content contains unprintable characters, replace them with a space
            string filtered_content = "";
            foreach (char c; content) {
                if (!isPrintable(c)) {
                    filtered_content ~= "?";
                } else {
                    filtered_content ~= c;
                }
            }
            return content;
        }

        // truncation
        if (max_length > 0 && description.length > max_length) {
            return description[0 .. max_length] ~ "...";
        }
        return description;
    }

    string to_string()
    {
        return format(
            "Pet: %s, Species: %s, Breed: %s, Color: %s, Description: %d characters",
            nick_name,
            species,
            breed,
            color,
            get_description().length
        );
    }

    int get_image_width()
    {
        return image_width;
    }

    int get_image_height()
    {
        return image_height;
    }

    ulong get_image_file_size()
    {
        if (image_path == "") {
            return 0;
        }

        auto file = File(image_path, "rb");
        return file.size();
    }

    string get_image_bytes()
    {
        if (image_path == "") {
            return "";
        }

        // ensure that the image path is valid
        if (!exists(image_path)) {
            return "";
        }

        auto file = File(image_path, "rb");
        auto buf = file.rawRead(new ubyte[file.size()]);
        // convert the buffer to a hex string, a new line every 16 bytes
        string hex_string = "";
        int i = 0;
        foreach (ubyte b; buf) {
            i++;
            hex_string ~= format("%02x", b);
            if (i % 32 == 0) {
                hex_string ~= "\n";
            }
        }
        return hex_string;
    }
}

Pet[] pets;

int menu(string user_name)
{
    writefln("\nWelcome to the Pet Shop, %s!", user_name);
    writefln("=======================================");
    int cnt = 0;
    foreach (Pet pet; pets) {
        if (!pet.is_delisted()) {
            cnt++;
        }
    }
    writefln("  There are %d pets registered", cnt);
    writefln("=======================================");
    writefln("%d. Register a new pet", MenuChoice.RegisterPet);
    writefln("%d. List all pets", MenuChoice.ListPets);
    writefln("%d. Delist a pet", MenuChoice.DelistPets);
    writefln("%d. Update pet description & more", MenuChoice.UpdatePetDescription);
    writefln("%d. Print a message about a pet", MenuChoice.PrintPet);
    writefln("%d. Register a new printer", MenuChoice.RegisterPrinter);
    writefln("%d. List all printers", MenuChoice.ListPrinters);
    writefln("%d. Delete a printer", MenuChoice.DeletePrinter);
    writefln("%d. Exit", MenuChoice.Exit);
    writefln("=======================================");
    writef("Enter your choice (%d-%d): ", MenuChoice.min, MenuChoice.Exit);
    stdout.flush();

    // Get the user's choice
    try {
        string choice_str = readln();
        if (choice_str.length == 0) {
            // EOF
            return MenuChoice.Exit;
        }
        int choice = strip(choice_str).to!int;
        return choice;
    } catch (Exception ex) {
        return -1;
    }
}

void register_pet(string user_name)
{
    writefln("Registering a new pet under %s.\n", user_name);

    write("Enter the pet's nickname: ");
    stdout.flush();
    string nick_name = strip(readln());

    writeln("  Available species:");
    foreach (int i; PetSpecies.min .. PetSpecies.max) {
        writefln("    %s", i.to!PetSpecies);
    }

    PetSpecies species;
    write("Enter the pet's species: ");
    stdout.flush();
    try {
        species = strip(readln()).to!PetSpecies;
    } catch (Exception ex) {
        writefln("Invalid species");
        return;
    }

    write("Enter the pet's breed: ");
    stdout.flush();
    string breed = strip(readln());

    write("Enter the pet's color: ");
    stdout.flush();
    string color = strip(readln());

    write("Enter the pet's description: ");
    stdout.flush();
    string description = strip(readln());

    /*
    if (description.length > MAX_DESCRIPTION_CHARS) {
        writefln("[DEBUG] Description is too long, will be saved to disk");
    } else {
        writefln("[DEBUG] Description is within the character limit, will be saved in memory");
    }
    */

    if (!is_valid_nickname(nick_name)) {
        writefln("Invalid nickname for your pet. We are very sorry for the inconvenience. Please try again.");
        return;
    }

    pets ~= new Pet(nick_name, species, breed, color, description);
    writefln("Pet %s registered successfully!", nick_name);
}

void update_pet_description(string user_name)
{
    writefln("Updating the description of a pet owned by %s...", user_name);

    list_pets(user_name, false);

    writefln("Please enter the pet ID to update: ");
    stdout.flush();
    int pet_id = strip(readln()).to!int;

    if (pet_id < 0 || pet_id >= pets.length || pets[pet_id].is_delisted()) {
        writefln("Invalid pet ID");
        return;
    }

    Pet pet = pets[pet_id];

    writefln("Please enter the new name for %s (leave blank to keep the current name):", pet.nick_name);
    stdout.flush();
    string new_nick_name = strip(readln());
    if (new_nick_name.length > 0) {
        // Vulnerability: We update the pet name regardless
        pet.nick_name = new_nick_name;
        if (!is_valid_nickname(pet.nick_name)) {
            writefln("Invalid nickname for your pet. We are very sorry for the inconvenience. Please try again.");
            pet.delist();
            return;
        }
    }

    writefln("Please enter the new description for %s: ", pet.nick_name);
    stdout.flush();
    string new_description = strip(readln());
    
    if (new_description.length > MAX_DESCRIPTION_CHARS) {
        writefln("[DEBUG] Description is too long, will be saved to disk");
    } else {
        writefln("[DEBUG] Description is within the character limit, will be saved in memory");
    }

    pet.description = new_description;
    pet.save_description();

    // update the pet's image
    writefln("Do you want to upload a new image for %s? (y/N): ", pet.nick_name);
    stdout.flush();
    string answer = strip(readln());
    if (answer == "y") {
        writefln("Due to the on-going tradewar, we only accept 8-bit bitmaps with a maximum size of 1024x1024 pixels.\n");
        writefln("Please enter the URL to the new image (http://example.com/image.bmp): ");
        stdout.flush();
        string new_image_path = strip(readln());

        // Use wget to download the image and save it to /tmp
        string image_name;
        string domain_name_and_path;
        if (new_image_path[0 .. 7] == "http://") {
            domain_name_and_path = new_image_path[7 .. $];
        } else if (new_image_path[0 .. 8] == "https://") {
            domain_name_and_path = new_image_path[8 .. $];
        } else {
            // invalid URL
            return;
        }
        string[] parts = domain_name_and_path.split("/");
        image_name = parts[parts.length - 1];
        if (image_name == "") {
            image_name = format("image_%s.bmp", pet.nick_name);
        }

        try {
            auto result = execute(["wget", "-T", "3", "-O", "/tmp/" ~ image_name, new_image_path]);
            if (result.status != 0) {
                writefln("Failed to download the image. Please check the URL and try again.");
                return;
            }
        } catch (Exception ex) {
            writefln("Failed to download the image. Please check the URL and try again.");
            return;
        }

        // check if the image is a valid 8-bit bitmap
        auto file = File("/tmp/" ~ image_name, "rb");
        auto buf = file.rawRead(new ubyte[file.size()]);
        file.close();

        // check if the image is a valid 8-bit bitmap
        int width = 0, height = 0, bits_per_pixel = 0;
        ubyte[] pixel_array;
        bool is_valid_bitmap = parse_bitmap(buf, width, height, bits_per_pixel, pixel_array);
        if (!is_valid_bitmap) {
            writefln("Invalid image format. Note that we only accept 8-bit bitmaps. "
                ~"Please try again (Have you ever used MS Paint?).");
            return;
        }

        if (width > 1024 || height > 1024) {
            writefln("Image size (%d x %d) is too large. Please try again.", width, height);
            return;
        }

        pet.image_width = width;
        pet.image_height = height;

        // save the image array to the current directory
        // VULN: Since we do not overwrite existing files, this allows leaking arbitrary files
        // under the current directory
        if (!exists(image_name)) {
            auto file_write = File(image_name, "wb");
            file_write.write(pixel_array);
            file_write.close();
            writefln("Image %s saved successfully!", image_name);
        }
        else {
            writefln("Image %s already exists. Please specify a new name.", image_name);
        }

        pet.image_path = image_name;
    }
}

// All printers go here
Printer[] printers;

void register_printer(string user_name)
{
    writefln("Registering a new printer...");

    write("Enter the printer's IP address and port (e.g., 192.168.1.1:631): ");
    stdout.flush();
    string ip_address_and_port = strip(readln());
    string[] parts = ip_address_and_port.split(":");
    if (parts.length != 2) {
        writefln("Invalid IP address and port");
        return;
    }
    string ip_address = parts[0];
    ushort port = parts[1].to!ushort;

    auto printer = new Printer(ip_address, port);

    // Let's talk to the printer!
    if (printer.test_connection()) {
        printers ~= printer;
        writefln("Printer registered successfully!");
    } else {
        writefln("Failed to communicate with the printer. Please check the IP address and port, and ensure the \n"
            ~"printer is online and accepting connections.");
    }
}

void list_printers(string user_name)
{
    writefln("Registered printers under %s:", user_name);
    foreach (ulong i; 0 .. printers.length) {
        writefln("  %d. %s", i, printers[i].to_string());
    }
}

void delete_printer(string user_name)
{
    writefln("Deleting a printer...");

    list_printers(user_name);

    write("Please enter the printer ID to delete: ");
    stdout.flush();
    int printer_id = strip(readln()).to!int;

    if (printer_id < 0 || printer_id >= printers.length) {
        writefln("Invalid printer ID");
        return;
    }

    printers = printers[0 .. printer_id] ~ printers[printer_id + 1 .. $];
    writefln("Printer deleted successfully!");
}

string create_pdf_document(Pet pet)
{
    // Create a temporary PostScript file for the pet information
    string ps_path = "/tmp/pet_info.ps";

    string image = "(The owner did not upload a picture) show\n";
    string image_hexbytes = pet.get_image_bytes();
    if (pet.get_image_width() > 0 && pet.get_image_height() > 0 && image_hexbytes.length > 0) {
        image = format(
            "(Picture name: %s) show\n"
            ~"1 1 scale\n"
            ~"%d %d 8 [1 0 0 -1 72 565]\n"
            ~"{ currentfile %d string readhexstring pop }\n"
            ~"false 3 colorimage\n"
            ~"%s",
            pet.image_path,
            pet.get_image_width(),
            pet.get_image_height(),
            pet.get_image_file_size(),
            image_hexbytes
        );
    }

    // format the description if it's too long
    int line_width = 50;
    string description = pet.get_description(400);  // the flag is not going to be over 400 characters
    string desc_lines = "";
    int description_begin_y = 585;
    int i = 0;
    foreach (ch; description) {
        if (i % line_width == 0) {
            desc_lines ~= format("72 %d moveto\n(", description_begin_y);
            description_begin_y -= 15;
        }
        if (ch == '\n') {
            // insert an artificial newline
            i = 0;
        } else {
            desc_lines ~= ch;
            i++;
        }
        if (i % line_width == 0) {
            desc_lines ~= ") show\n";
        }
    }
    if (i % line_width != 0) {
        desc_lines ~= ") show\n";
    }
    description_begin_y -= 15;
    desc_lines ~= format("72 %d moveto\n", description_begin_y);

    // The PostScript file
    string content = format(
        "/Courier %% the font\n"
        ~"40 selectfont\n"
        ~"72 700 moveto\n"
        ~"(Pet Information) show\n"
        ~"72 680 moveto\n"
        ~"/Courier\n"
        ~"14 selectfont\n"
        ~"(--------------------------------------------------) show\n"
        ~"72 660 moveto\n"
        ~"(Name: %s) show\n"
        ~"72 645 moveto\n"
        ~"(Species: %s) show\n"
        ~"72 630 moveto\n"
        ~"(Breed: %s) show\n"
        ~"72 615 moveto\n"
        ~"(Color: %s) show\n"
        ~"72 600 moveto\n"
        ~"(Description:) show\n\n"
        ~"%s\n"
        ~"(Picture: %d x %d) show\n\n"
        ~"72 %d moveto\n"
        ~"%s\n"
        ~"showpage\n",
        pet.nick_name, pet.species, pet.breed, pet.color, desc_lines,
        pet.get_image_width(), pet.get_image_height(), description_begin_y - 15, image
    );

    auto ps = File(ps_path, "w");
    ps.write(content);
    ps.close();

    // Convert the PostScript file to a PDF file using ghostscript
    string pdf_path = "/tmp/pet_info.pdf";
    string command = format("gs -o %s "
        ~"-sDEVICE=pdfwrite "
        ~"-dAutoFilterColorImages=false "
        ~"-dAutoFilterGrayImages=false "
        ~"-dColorImageFilter=/FlateEncode "
        ~"-dGrayImageFilter=/FlateEncode "
        ~"-dSAFER "
        ~"%s",
        pdf_path,
        ps_path
    );
    auto result = executeShell(command);

    if (result.status != 0) {
        writefln("Failed to convert PostScript to PDF");
        return "";
    }

    return pdf_path;
}

void print_pet(string user_name)
{
    list_pets(user_name, false);

    write("Please enter the pet ID to print: ");
    stdout.flush();
    int pet_id = strip(readln()).to!int;

    // Vulnerability: We don't check if the pet is delisted
    if (pet_id < 0 || pet_id >= pets.length) {
        writefln("Invalid pet ID");
        return;
    }

    Pet pet = pets[pet_id];
    writefln("Printing detailed information about %s...", pet.nick_name);

    // specify a printer to use
    write("Please enter the printer ID to use: ");
    stdout.flush();
    int printer_id = strip(readln()).to!int;

    if (printer_id < 0 || printer_id >= printers.length) {
        writefln("Invalid printer ID");
        return;
    }

    string pdf_path = create_pdf_document(pet);
    if (pdf_path == "") {
        writefln("Failed to create a PDF document for printing");
        return;
    }

    Printer printer = printers[printer_id];
    writefln("Printing to %s...", printer);

    // Print the document
    if (printer.print_document(pdf_path)) {
        writefln("Print job sent successfully!");
    } else {
        writefln("Failed to send print job.");
    }
}

void list_pets(string user_name, bool caption = true)
{
    if (caption) {
        writefln("Listing all %d pets owned by %s.", pets.length, user_name);
    }

    int i = 0;
    foreach (Pet pet; pets) {
        if (pet.is_delisted()) {
            i++;
            continue;
        }
        writefln("  %d. %s: %s %s %s [%s]",
            i++,
            pet.species,
            pet.nick_name,
            pet.breed,
            pet.color,
            pet.is_description_in_file() ? "in file" : "in memory"
        );
    }
}

void delist_pets(string user_name)
{
    writefln("Delisting a pet owned by %s.", user_name);
    list_pets(user_name, false);

    writefln("Please enter the pet ID to delist: ");
    int pet_id = strip(readln()).to!int;

    if (pet_id < 0 || pet_id >= pets.length) {
        writefln("Invalid pet ID");
        return;
    }

    auto pet = pets[pet_id];
    if (pet.is_delisted()) {
        writefln("Invalid pet ID");
    }
    pet.delist();
    writefln("Pet %s owned by %s is delisted.", pet.nick_name, user_name);
}

string extract_second_flag()
{
    string chunk0 = "flag{8_8_international_cat_day_";
    string chunk1 = "d6022f2cddcda458f8ddec3e99881ae2";
    string chunk2 = "}";

    // naughty
    auto md5 = new MD5Digest();
    ubyte[] hash = md5.digest(chunk1);
    chunk1 = toHexString(hash);

    string flag = chunk0 ~ chunk1 ~ chunk2;
    return flag;
}

void print_second_flag()
{
    if (environment.get("ed4679f97385f33be64e7a38e486c8") == "1495903dc7db4a2f28fa28cc3d19b32d33") {
        // extract the flag
        string flag = extract_second_flag();
        writefln("Here is your reward: %s", flag);
    }
}

int main()
{
    /*
    auto pet = new Pet("test", PetSpecies.Dog, "test", "test", "test");
    pet.image_width = 600;
    pet.image_height = 400;
    pet.image_path = "petshop";
    create_pdf_document(pet);
    */

    // Get user name from stdin
    write("Welcome to Petshop!\n\nPlease enter your name: ");
    stdout.flush();
    string user_name = strip(readln());

    bool should_exit = false;

    // Print the menu
    while (!should_exit) {
        int choice = menu(user_name);
        writeln("");

        // Handle the user's choice
        switch (choice)
        {
            case MenuChoice.RegisterPet:
                register_pet(user_name);
                break;
            case MenuChoice.ListPets:
                list_pets(user_name);
                break;
            case MenuChoice.DelistPets:
                delist_pets(user_name);
                break;
            case MenuChoice.UpdatePetDescription:
                update_pet_description(user_name);
                break;
            case MenuChoice.PrintPet:
                print_pet(user_name);
                break;
            case MenuChoice.RegisterPrinter:
                register_printer(user_name);
                break;
            case MenuChoice.ListPrinters:
                list_printers(user_name);
                break;
            case MenuChoice.DeletePrinter:
                delete_printer(user_name);
                break;
            case MenuChoice.Exit:
                should_exit = true;
                writeln("See you next time!");
                break;
            case MenuChoice.PrintSecondFlag:
                print_second_flag();
                break;
            default:
                writefln("Invalid choice");
        }
    }

    return 0;
}
