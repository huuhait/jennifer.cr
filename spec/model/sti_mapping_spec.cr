require "../spec_helper"

describe Jennifer::Model::STIMapping do
  describe "%mapping" do
    context "types" do
      context "nillable" do
        context "using ? without named tuple" do
          it "parses type as nillable" do
            typeof(Factory.build_facebook_profile.uid).should eq(String?)
          end
        end

        context "using :null option" do
          it "parses type as nilable" do
            typeof(Factory.build_twitter_profile.email).should eq(String?)
          end
        end
      end
    end

    pending "defines default constructor if all fields are nilable or have default values and superclass has default constructor" do
      TwitterProfile::WITH_DEFAULT_CONSTRUCTOR.should be_true
    end

    it "doesn't define default constructor if all fields are nilable or have default values" do
      TwitterProfile::WITH_DEFAULT_CONSTRUCTOR.should be_false
    end
  end

  describe "#initialize" do
    context "ResultSet" do
      it "properly loads from db" do
        f = c = Factory.create_facebook_profile(uid: "1111", login: "my_login")
        res = FacebookProfile.find!(f.id)
        res.uid.should eq("1111")
        res.login.should eq("my_login")
      end
    end

    context "hash" do
      it "properly loads from hash" do
        f = FacebookProfile.build({:login => "asd", :uid => "uid"})
        f.type.should eq("FacebookProfile")
        f.login.should eq("asd")
        f.uid.should eq("uid")
      end
    end
  end

  describe "::field_names" do
    it "returns all fields" do
      names = FacebookProfile.field_names
      names.includes?("login").should be_true
      names.includes?("uid").should be_true
      names.includes?("type").should be_true
      names.includes?("contact_id").should be_true
      names.includes?("id").should be_true
      names.size.should eq(5)
    end
  end

  describe "#all" do
    it "generates correct query" do
      q = FacebookProfile.all
      q.as_sql.should eq("profiles.type = %s")
      q.sql_args.should eq(db_array("FacebookProfile"))
    end
  end

  describe "#to_h" do
    it "sets all fields" do
      r = c = Factory.create_facebook_profile(uid: "111", login: "my_login").to_h
      r.has_key?(:id).should be_true
      r[:login].should eq("my_login")
      r[:type].should eq("FacebookProfile")
      r[:uid].should eq("111")
    end
  end

  describe "#to_str_h" do
    it "sets all fields" do
      r = Factory.build_facebook_profile(uid: "111", login: "my_login").to_str_h
      r["login"].should eq("my_login")
      r["type"].should eq("FacebookProfile")
      r["uid"].should eq("111")
    end
  end

  describe "#attribute" do
    it "returns attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("uid").should eq("111")
    end

    it "returns parent attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("login").should eq("my_login")
    end
  end

  describe "#arguments_to_save" do
    it "returns named tuple with correct keys" do
      r = Factory.build_twitter_profile.arguments_to_save
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with empty arguments if no field was changed" do
      r = Factory.build_twitter_profile.arguments_to_save
      r[:args].empty?.should be_true
      r[:fields].empty?.should be_true
    end

    it "returns tuple with changed parent argument" do
      c = Factory.build_twitter_profile
      c.login = "some new login"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new login"))
      r[:fields].should eq(db_array("login"))
    end

    it "returns tuple with changed own argument" do
      c = Factory.build_twitter_profile
      c.email = "some new email"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new email"))
      r[:fields].should eq(db_array("email"))
    end
  end

  describe "#arguments_to_insert" do
    it "returns named tuple with :args and :fields keys" do
      r = Factory.build_twitter_profile.arguments_to_insert
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with all fields" do
      r = Factory.build_twitter_profile.arguments_to_insert
      match_array(r[:fields], %w(login contact_id type email))
    end

    it "returns tuple with all values" do
      r = Factory.build_twitter_profile.arguments_to_insert
      match_array(r[:args], db_array("some_login", nil, "TwitterProfile", "some_email@example.com"))
    end
  end
end
