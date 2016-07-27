local Modules       = {
  Achievements      = {
    LibName         = "achievements";
    Functions       = {
      Create        = {
        "GID";
        "ID";
        "Description";
        "Name";
        "Reward";
        "Icon";
      };
      Award         = {
        "GID";
        "PlayerID";
        "ID";
      };
      List          = {
        "GID";
        "GameID";
        "Filter";
      };
      GetReward     = {
        "GID";
      };
    };
  };

  Auth              = {
    SkipAuth        = true;
    LibName         = "check_cokey";
    Functions       = {
      Check         = {
        "GID";
        "CoKey";
        "UID";
      };
      CheckNoUID    = {
        "GID";
        "CoKey";
      };
    };
  };

  Loadstring        = {
    LibName         = "create_mainmodule";
    Functions       = {
      Load          = {
        "Source";
        {NoRequire = true; Name = "ID"; Default = 0};
      };
      LockAsset     = {
        "ID";
      };
    };
  };

  Messages          = {
    LibName         = "message_manager";
    Functions       = {
      AddMessage    = {
        "User";
        "Message";
        "GID";
      };
      CheckMessages = {
        "Since";
        {NoRequire = true; Name = "Fresh"; Default = false};
        "GIDFilter";
      };
    };
  };

  PlayerInfo        = {
    LibName         = "userinfo";
    Functions       = {
      GetUserInfo   = {
        "ID";
      };
      TryCreateUser = {
        "ID";
      };
    };
  };

  Friends           = {
    LibName         = "friends";
    Functions       = {
      GetFriends    = {
        "ID";
      };
      SetOnlineGame = {
        "ID";
        "Game";
        "Name";
      };
      GoOffline     = {
        "ID";
        "TimeInGame";
        "GID";
      };
    };
  };

  DataStore         = {
    LibName         = "data_store";
    Functions       = {
      SaveData      = {
        "GID";
        "Key";
        "Value";
      };
      LoadData      = {
        "GID";
        "Key";
      };
      GetSpace      = {
        "GID";
      };
      ListKeys      = {
        "GID";
      };
    };
  };

  Bans              = {
    LibName         = "bans";
    Functions       = {
      CreateGlobalBan     = {
        "GID";
        "Player";
        "Reason";
        "Meta";
        "Secret";
      };
      IsBanned      = {
        "Player";
        "GID";
      };
      CreateLocalBan = {
        "GID";
        "Player";
        "Reason";
      };
      RemoveLocalBan = {
        "GID";
        "Player";
      };
    };
  };
};

return Modules;
