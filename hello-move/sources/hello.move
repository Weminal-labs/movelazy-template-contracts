module hello_addr::hello {
    use std::string;
    use std::signer;
    
    // Resource struct that holds the greeting message
    struct HelloMessage has key {
        message: string::String
    }

    // Initialize the greeting message
    public entry fun initialize(account: &signer) {
        let hello_message = HelloMessage {
            message: string::utf8(b"Hello, Aptos!")
        };
        move_to(account, hello_message);
    }

    // Update the greeting message
    public entry fun set_message(account: &signer, new_message: string::String) acquires HelloMessage {
        let hello_message = borrow_global_mut<HelloMessage>(signer::address_of(account));
        hello_message.message = new_message;
    }

    // Read the greeting message
    #[view]
    public fun get_message(addr: address): string::String acquires HelloMessage {
        borrow_global<HelloMessage>(addr).message
    }

    #[test_only]
    use std::string;

    #[test(admin = @0x123)]
    public fun test_initialize(admin: &signer) acquires HelloMessage {
        // Initialize the message
        initialize(admin);
        
        // Verify the message is set correctly
        let message = get_message(@0x123);
        assert!(message == string::utf8(b"Hello, Aptos!"), 0);
    }

    #[test(admin = @0x123)]
    public fun test_set_message(admin: &signer) acquires HelloMessage {
        // First initialize
        initialize(admin);
        
        // Update the message
        let new_message = string::utf8(b"Hello, Move!");
        set_message(admin, new_message);
        
        // Verify the message was updated
        let message = get_message(@0x123);
        assert!(message == string::utf8(b"Hello, Move!"), 1);
    }

    #[test(admin = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x50001)]
    public fun test_set_message_by_other_account(
        admin: &signer,
        other: &signer
    ) acquires HelloMessage {
        // First initialize with admin account
        initialize(admin);
        
        // Try to update message with other account (should fail)
        let new_message = string::utf8(b"Hello from other!");
        set_message(other, new_message);
    }
} 