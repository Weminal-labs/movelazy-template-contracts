// >>>>>>>>>> Start module <<<<<<<<<<
module twitter_addr::twitter {
    // >>>>>>>>>> Start imports <<<<<<<<<<
    use std::string::{String};
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::object;
    use aptos_framework::object::{Object};
    use std::vector;
    // >>>>>>>>>> End imports <<<<<<<<<<

    // >>>>>>>>>> Start errors <<<<<<<<<<
    const ENot_Init: u64 = 1;
    const EAlready_Init: u64 = 2;
    const ENot_Tweet_Owner: u64 = 3;
    const ETweet_Not_Exist: u64 = 4;
    // >>>>>>>>>> End errors <<<<<<<<<<

    // >>>>>>>>>> Start structs <<<<<<<<<<
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Tweet has key {
        content: String,
        created_at: u64,
        author: address
    }

    struct UserTweets has key {
        tweet_count: u64,
        tweet_events: event::EventHandle<Object<Tweet>>,
        tweet_addresses: vector<address>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Comment has key {
        content: String,
        created_at: u64,
        author: address,
        tweet_addr: address
    }

    struct UserComments has key {
        comment_count: u64,
        comment_events: event::EventHandle<Object<Comment>>,
        comment_addresses: vector<address>,
    }

    struct TweetCommentPair has store, drop, copy {
        tweet_addr: address,
        comment_addrs: vector<address>
    }

    struct UserRegistry has key {
        users_with_comments: vector<address>
    }
    // >>>>>>>>>> End structs <<<<<<<<<<

    // >>>>>>>>>> Start initialize functions <<<<<<<<<<
    public entry fun initialize_user(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<UserTweets>(addr), EAlready_Init);
        
        move_to(account, UserTweets {
            tweet_count: 0,
            tweet_events: account::new_event_handle<Object<Tweet>>(account),
            tweet_addresses: vector::empty<address>(),
        });
    }

    public entry fun initialize_user_comments(account: &signer) acquires UserRegistry {
        let addr = signer::address_of(account);
        assert!(!exists<UserComments>(addr), EAlready_Init);
        
        move_to(account, UserComments {
            comment_count: 0,
            comment_events: account::new_event_handle<Object<Comment>>(account),
            comment_addresses: vector::empty<address>(),
        });

        // Add user to registry
        let registry = borrow_global_mut<UserRegistry>(@twitter_addr);
        vector::push_back(&mut registry.users_with_comments, addr);
    }

    fun init_module(account: &signer) {
        move_to(account, UserRegistry {
            users_with_comments: vector::empty<address>()
        });
    }
    // >>>>>>>>>> End initialize functions <<<<<<<<<<

    // >>>>>>>>>> Start write functions <<<<<<<<<<
    public entry fun create_tweet(
        account: &signer,
        content: String,
    ) acquires UserTweets {
        let addr = signer::address_of(account);
        assert!(exists<UserTweets>(addr), ENot_Init);
        
        let constructor_ref = object::create_object(signer::address_of(account));
        let tweet_signer = object::generate_signer(&constructor_ref);
        let tweet_addr = object::address_from_constructor_ref(&constructor_ref);
        
        let tweet = Tweet {
            content,
            created_at: timestamp::now_seconds(),
            author: addr,
        };
        
        move_to(&tweet_signer, tweet);
        
        let user_tweets = borrow_global_mut<UserTweets>(addr);
        user_tweets.tweet_count = user_tweets.tweet_count + 1;
        vector::push_back(&mut user_tweets.tweet_addresses, tweet_addr);
        
        let tweet_obj = object::object_from_constructor_ref<Tweet>(&constructor_ref);
        event::emit_event(&mut user_tweets.tweet_events, tweet_obj);
    }

    public entry fun delete_tweet(
        account: &signer,
        tweet_address: address,
    ) acquires UserTweets, Tweet {
        let addr = signer::address_of(account);
        assert!(exists<UserTweets>(addr), ENot_Init);
        
        let tweet = borrow_global<Tweet>(tweet_address);
        assert!(tweet.author == addr, ENot_Tweet_Owner);
        
        let user_tweets = borrow_global_mut<UserTweets>(addr);
        user_tweets.tweet_count = user_tweets.tweet_count - 1;
        
        let (found, index) = vector::index_of(&user_tweets.tweet_addresses, &tweet_address);
        if (found) {
            vector::remove(&mut user_tweets.tweet_addresses, index);
        };
        
        let Tweet { content: _, created_at: _, author: _ } = move_from<Tweet>(tweet_address);
    }

    public entry fun create_comment(
        account: &signer,
        tweet_addr: address,
        content: String,
    ) acquires UserComments {
        let addr = signer::address_of(account);
        assert!(exists<UserComments>(addr), ENot_Init);
        // Verify tweet exists
        assert!(exists<Tweet>(tweet_addr), ETweet_Not_Exist);
        
        let constructor_ref = object::create_object(signer::address_of(account));
        let comment_signer = object::generate_signer(&constructor_ref);
        let comment_addr = object::address_from_constructor_ref(&constructor_ref);
        
        let comment = Comment {
            content,
            created_at: timestamp::now_seconds(),
            author: addr,
            tweet_addr
        };
        
        move_to(&comment_signer, comment);
        
        let user_comments = borrow_global_mut<UserComments>(addr);
        user_comments.comment_count = user_comments.comment_count + 1;
        vector::push_back(&mut user_comments.comment_addresses, comment_addr);
        
        let comment_obj = object::object_from_constructor_ref<Comment>(&constructor_ref);
        event::emit_event(&mut user_comments.comment_events, comment_obj);
    }
    // >>>>>>>>>> End write functions <<<<<<<<<<

    // >>>>>>>>>> Start read functions <<<<<<<<<<
    public fun get_tweet_count(addr: address): u64 acquires UserTweets {
        assert!(exists<UserTweets>(addr), ENot_Init);
        let user_tweets = borrow_global<UserTweets>(addr);
        user_tweets.tweet_count
    }

    #[view]
    public fun get_tweet_detail(tweet_address: address): (String, u64, address) acquires Tweet {
        let tweet = borrow_global<Tweet>(tweet_address);
        (
            tweet.content,
            tweet.created_at,
            tweet.author
        )
    }

    #[view]
    public fun get_all_tweets(user_address: address): vector<address> acquires UserTweets {
        assert!(exists<UserTweets>(user_address), ENot_Init);
        let user_tweets = borrow_global<UserTweets>(user_address);
        *&user_tweets.tweet_addresses
    }

    #[view]
    public fun get_comment_detail(comment_address: address): (String, u64, address, address) acquires Comment {
        let comment = borrow_global<Comment>(comment_address);
        (
            comment.content,
            comment.created_at,
            comment.author,
            comment.tweet_addr
        )
    }

    #[view]
    public fun get_tweet_comments(tweet_address: address): vector<address> 
    acquires UserComments, Comment, UserRegistry {
        let comments = vector::empty<address>();
        let users = get_users_with_comments();
        
        let i = 0;
        while (i < vector::length<address>(&users)) {
            let user_addr = *vector::borrow(&users, i);
            if (exists<UserComments>(user_addr)) {
                let user_comments = borrow_global<UserComments>(user_addr);
                let j = 0;
                while (j < vector::length(&user_comments.comment_addresses)) {
                    let comment_addr = *vector::borrow(&user_comments.comment_addresses, j);
                    let comment = borrow_global<Comment>(comment_addr);
                    if (comment.tweet_addr == tweet_address) {
                        vector::push_back(&mut comments, comment_addr);
                    };
                    j = j + 1;
                };
            };
            i = i + 1;
        };
        
        comments
    }

    fun get_users_with_comments(): vector<address> acquires UserRegistry {
        let registry = borrow_global<UserRegistry>(@twitter_addr);
        *&registry.users_with_comments
    }

    #[view]
    public fun get_user_tweets_with_comments(user_address: address): vector<TweetCommentPair> 
    acquires UserTweets, UserComments, Comment, UserRegistry {
        assert!(exists<UserTweets>(user_address), ENot_Init);
        let user_tweets = borrow_global<UserTweets>(user_address);
        let result = vector::empty<TweetCommentPair>();
        
        let i = 0;
        while (i < vector::length(&user_tweets.tweet_addresses)) {
            let tweet_addr = *vector::borrow(&user_tweets.tweet_addresses, i);
            let comments = get_tweet_comments(tweet_addr);
            let pair = TweetCommentPair {
                tweet_addr,
                comment_addrs: comments
            };
            vector::push_back(&mut result, pair);
            i = i + 1;
        };
        
        result
    }
    // >>>>>>>>>> End read functions <<<<<<<<<<
}
// >>>>>>>>>> End module <<<<<<<<<<
