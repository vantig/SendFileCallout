public class YotiOptions {

    public class Reminders {
        public Integer frequency;
    }

    public class Recipient {
        public Recipient(String name, String email, List<Tag> tags) {
            this.tags = tags;
            this.name = name;
            this.email = email;

        }
        public String name;
        public String email;
        public String role;
        public String auth_type;
        public Integer sign_group;
        public List<Tag> tags;
        public String country_code;
        public String phone_number;
        public Witness witness;
    }


    public class Invitation {
        public Body body;
    }

    public class Witness {
        public List<Tags_Z> tags;
    }

    public class Tags_Z {
    }

    public class Emails {
        public Invitation invitation;
        public Reminders reminders;
    }

    public class Body {
        public String message;
    }

    public class Notifications {
        public String destination;
        public List<String> subscriptions;
    }

    public class Tag {
        public Integer page_number;
        public Double x;
        public Double y;
        public String type;
        public Boolean optional;
        public String file_name;
    }

    public String name;
    public Emails emails;
    public Boolean has_envelope_otps;
    public List<Recipient> recipients;
    public Notifications notifications;

    public static YotiOptions parse(String json) {
        return (YotiOptions) System.JSON.deserialize(json, YotiOptions.class);
    }
}