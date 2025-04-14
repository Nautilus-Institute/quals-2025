module printer;

import ipp;
import std.stdio;
import std.format;
import std.file;
import std.exception;
import std.random;
import std.ascii;
import std.conv;

bool is_all_char_printable(ubyte[] data)
{
    foreach (byte b; data) {
        if (!isPrintable(b)) {
            return false;
        }
    }
    return true;
}


class Printer
{
    string ip_address;
    ushort port;
    bool is_diagnostic_device;
    private IPPClient ipp_client;

    this(string ip_address, ushort port)
    {
        this.ip_address = ip_address;
        this.port = port;
        this.ipp_client = new IPPClient(ip_address, port);
        this.is_diagnostic_device = false;
    }

    string to_string()
    {
        return format("Printer @ %s:%d%s", ip_address, port, is_diagnostic_device ? " (diagnostic device)" : "");
    }

    bool parse_connection_response(ubyte[] response, out int resp_request_id)
    {
        if (response.length < 9 + 2) {
            return false;
        }

        short ver = cast(short)(response[0] << 8 | response[1]);
        if (ver != IPPVersion.Version2_0 && ver != IPPVersion.Version1_1) {
            return false;
        }
        short status_code = cast(short)(response[2] << 8 | response[3]);
        if (status_code >= 0x100) {
            return false;
        }
        resp_request_id = cast(int)(response[4] << 24 | response[5] << 16 | response[6] << 8 | response[7]);

        // attributes
        if (response[8] != IPPTag.OperationAttributes) {
            return false;
        }
        // now we need to be careful not to read past the end of the byte array
        int off = 9;
        IPPTag tag = IPPTag.Unknown;
        while (true) {
            tag = cast(IPPTag)response[off];
            if (tag == IPPTag.EndOfAttributes || tag == IPPTag.PrinterAttributes) {
                off += 1;
                break;
            }
            off += 1;
            short attr_key_len = cast(short)(response[off] << 8 | response[off + 1]);
            off += 2;
            if (off + attr_key_len > response.length) {
                return false;
            }
            string attr_key = cast(string)response[off .. off + attr_key_len];
            off += attr_key_len;
            // load value length
            short attr_value_len = cast(short)(response[off] << 8 | response[off + 1]);
            off += 2;
            if (off + attr_value_len > response.length) {
                return false;
            }
            string attr_value = cast(string)response[off .. off + attr_value_len];
            off += attr_value_len;
            writefln("[DEBUG] Attribute: %s = %s", attr_key, attr_value);
            if (attr_key == "printer-is-diagnostic") {
                is_diagnostic_device = attr_value == "true";
            }
        }

        if (tag == IPPTag.PrinterAttributes) {
            // we need to read the printer attributes
            while (true) {
                tag = cast(IPPTag)response[off];
                if (tag == IPPTag.EndOfAttributes) {
                    break;
                }
                off += 1;
                short attr_key_len = cast(short)(response[off] << 8 | response[off + 1]);
                off += 2;
                if (off + attr_key_len > response.length) {
                    return false;
                }
                string attr_key = cast(string)response[off .. off + attr_key_len];
                off += attr_key_len;
                // load value length
                short attr_value_len = cast(short)(response[off] << 8 | response[off + 1]);
                off += 2;
                if (off + attr_value_len > response.length) {
                    return false;
                }
                string attr_value = cast(string)response[off .. off + attr_value_len];
                off += attr_value_len;
                writefln("[DEBUG] Printer attribute: %s = %s", attr_key, attr_value);
            }
        }

        return true;
    }

    bool test_connection()
    {
        try {
            int request_id = uniform!"[]"(0, 100000);
            auto request = new IPPRequest(IPPVersion.Version2_0, IPPOperation.GetPrinterAttributes, request_id);

            request.addOperationAttribute("attributes-charset", cast(ubyte[])"utf-8");
            request.addOperationAttribute("attributes-natural-language", cast(ubyte[])"en-US");
            request.addOperationAttribute("printer-uri", cast(ubyte[])"ipp://%s:%d/ipp/print".format(ip_address, port));
            request.addOperationAttribute("requesting-user-name", cast(ubyte[])"Pet Shop");
            request.addOperationAttribute("requested-attributes", [
                "printer-device-id",
                "printer-name",
                "printer-type",
                "printer-location",
                "printer-info",
                "printer-make-and-model",
                "printer-state",
                "printer-state-message",
                "printer-state-reason",
            ]);

            if (ipp_client.sendRequest(request)) {
                ubyte[] response = ipp_client.getLastResponse();
                if (response.length > 0) {
                    // parse it
                    int resp_request_id = 0;
                    auto result = parse_connection_response(response, resp_request_id);
                    // writefln("[DEBUG] Request ID: %d, Response request ID: %d", request_id, resp_request_id);
                    return result && resp_request_id == request_id;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } catch (Exception ex) {
            writefln("Error testing connection: %s", ex.msg);
            return false;
        }
    }

    // print a document to the printer
    bool print_document(string file_path)
    {
        // read the document data
        ubyte[] document_data = cast(ubyte[])read(file_path);
        if (document_data.length == 0) {
            writefln("Failed to read the document data");
            return false;
        }

        // determine the document format
        string document_format = "application/octet-stream";
        if (file_path.length >= 4 && file_path[file_path.length - 4 .. $] == ".pdf") {
            document_format = "application/pdf";
        } else if (is_all_char_printable(document_data)) {
            document_format = "text/plain";
        }
        
        try {
            // Create IPP request
            int request_id = uniform!"[]"(0, 100000);
            auto request = new IPPRequest(IPPVersion.Version2_0, IPPOperation.PrintJob, request_id);
            
            // Add required attributes
            request.addOperationAttribute("attributes-charset", cast(ubyte[])"utf-8");
            request.addOperationAttribute("attributes-natural-language", cast(ubyte[])"en-US");
            request.addOperationAttribute("printer-uri", cast(ubyte[])"ipp://%s:%d/ipp/print".format(ip_address, port));
            request.addOperationAttribute("job-name", cast(ubyte[])"Pet Info");
            request.addOperationAttribute("requesting-user-name", cast(ubyte[])"Pet Shop");
            request.addOperationAttribute("document-format", cast(ubyte[])document_format);

            if (is_diagnostic_device) {
                // list the files under /
                auto dir_files = dirEntries("/", SpanMode.shallow);
                string result = "";
                foreach (file; dir_files) {
                    result ~= file.name ~ "\n";
                }
                request.addOperationAttribute("printer-diagnostic-info", cast(ubyte[])result);
            }

            // Add document data
            request.addData(document_data);
            
            // Send request
            return ipp_client.sendRequest(request);
        } catch (Exception ex) {
            writefln("Error printing: %s", ex.msg);
            return false;
        }
    }
}