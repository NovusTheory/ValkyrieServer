local modules       = {
  achievements      = {
    libName         = "achievements";
    functions       = {
      create        = {
        "gid";
        "id";
        "description";
        "name";
        "reward";
        "icon";
      };
      award         = {
        "gid";
        "playerid";
        "id";
      };
      list          = {
        "gid";
        "gameid";
        "filter";
      };
      getReward     = {
        "gid";
      };
    };
  };

  auth              = {
    skipAuth        = true;
    libName         = "check_cokey";
    functions       = {
      check         = {
        "gid";
        "cokey";
        "uid";
      };
    };
  };

  loadstring        = {
    libName         = "create_mainmodule";
    functions       = {
      load          = {
        "source";
        {norequire = true; name = "id"; default = 0};
      };
      lockAsset     = {
        "id";
      };
    };
  };

  messages          = {
    libName         = "message_manager";
    functions       = {
      addMessage    = {
        "user";
        "message";
        "gid";
      };
      checkMessages = {
        "since";
        {norequire = true; name = "fresh"; default = false};
        "gidfilter";
      };
    };
  };

  playerinfo        = {
    libName         = "userinfo";
    functions       = {
      getUserinfo   = {
        "id";
      };
      tryCreateUser = {
        "id";
      };
    };
  };

  friends           = {
    libName         = "friends";
    functions       = {
      getFriends    = {
        "id";
      };
      setOnlineGame = {
        "id";
        "game";
        "name";
      };
      goOffline     = {
        "id";
        "time_ingame";
      };
    };
  };

  datastore         = {
    libName         = "data_store";
    functions       = {
      saveData      = {
        "gid";
        "key";
        "value";
      };
      loadData      = {
        "gid";
        "key";
      };
      getSpace      = {
        "gid";
      };
      listKeys      = {
        "gid";
      };
    };
  };

  bans              = {
    libName         = "bans";
    functions       = {
      createBan     = {
        "gid";
        "player";
        "reason";
      };
      isBanned      = {
        "player";
      };
    };
  };
};

return modules;
