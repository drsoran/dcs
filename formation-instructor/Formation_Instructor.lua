local updateInterval = 0.1;

--------------
-- Score
--------------

Score = {
  timeInFormation = 0
}

function Score:New()
  local o = {
    timeInFormation = 0
  };

  setmetatable(o, {__index = self});
  return o;
end

function Score:AddSecondsInFormation(seconds)
  self.timeInFormation = self.timeInFormation + seconds;
end

function Score:GetSecondsInFormation()
  return math.floor(self.timeInFormation);
end

function Score:Reset()
  self.timeInFormation = 0;
end

----------------
-- Formation
----------------

Position = {
  angles = {},
  distancesFT = {}
}

function Position:New(angles, distancesFT)
  local o = {
    angles = angles,
    distancesFT = distancesFT
  };

  setmetatable(o, {__index = self});
  return o;
end

Formation = {
  name = "",
  description = "",
  poitions = {}
}

function Formation:New(name, description, positions)
  local o = {
    name = name,
    description = description,
    positions = positions
  };

  setmetatable(o, {__index = self});
  return o;
end

function Formation:GetDescription()
  return string.format("%s: %s", self.name,  self.description);
end

----------------
-- Student
----------------

Student = {
  score = nil,
  number = 0,
  client = nil,
  angleToInstructor = 0,
  distanceToInstructorFT = 0,
  formation = nil
}

function Student:New(client, number)
  local o = {
    score = Score:New(),
    number = number,
    client = client,
    angleToInstructor = 0,
    distanceToInstructorFT = 0,
    formation = nil
  };

  setmetatable(o, {__index = self});
  return o;
end

function Student:IsAlive()
  return self.client:IsAlive();
end

function Student:GetScore()
  return self.score;
end

function Student:Update(instructor)
  self:calculateAngleAndDist(instructor);
end

function Student:SetFormation(formation)
  self.score:Reset();
  self.formation = formation;
end

function Student:GetFormation()
  return self.formation;
end

function Student:GetReportLine()
  local inZoneMarker = "   ";

  if (self.formation) then
    if (self:isInFormation()) then
      self.score:AddSecondsInFormation(updateInterval);
      if (self.score:GetSecondsInFormation() % 2 == 0) then
        inZoneMarker = ">> ";
      end
    end
  end

  local function formatDistance()
    if (self.distanceToInstructorFT < 6076) then -- 1 NM in ft
      return string.format('%d FT', self.distanceToInstructorFT);
    else
      return string.format('%.2f NM', UTILS.Round(self.distanceToInstructorFT / 6076.12, 2));
    end
  end

  local angleDistFmt = string.format('%03d°, %s', self.angleToInstructor, formatDistance());

  return string.format("%s#%d %s: %s, T: %s",
    inZoneMarker,
      self.number,
      self.client:GetPlayer(),
      angleDistFmt,
      UTILS.SecondsToClock(self.score:GetSecondsInFormation(), true));

end

function Student:toAngleLR(heading, fromCoordinate, toCoordinate)
  local dir = fromCoordinate:GetDirectionVec3(toCoordinate);
  local angle = fromCoordinate:GetAngleDegrees(dir);
  local aspect = angle - heading;

  if aspect > 180 then
    aspect = aspect - 360;
  end

  if (aspect >= 0 and aspect <= 180) then
    return 90 - aspect;
  end

  if (aspect < 0 and aspect >= -180) then
    return 90 + aspect;
  end

  return aspect;
end

function Student:calculateAngleAndDist(instructor)
  local pFrom = self.client:GetCoordinate();
  local pTo = instructor:GetCoordinate();
  self.distanceToInstructorFT = math.floor(UTILS.MetersToFeet(pFrom:Get2DDistance(pTo)));
  self.distanceToInstructorFT = self.distanceToInstructorFT - 33; -- substract 2 times wingspan half of the Viper (2 * 16ft)
  self.angleToInstructor = math.floor(self:toAngleLR(instructor:GetHeading(), pFrom, pTo));
end

function Student:isInFormation()
  local position = self.formation.positions[self.number];
  local inSpot
    = self.angleToInstructor >= position.angles[1]
      and self.angleToInstructor <= position.angles[2]
      and self.distanceToInstructorFT >= position.distancesFT[1]
      and self.distanceToInstructorFT <= position.distancesFT[2];

  return inSpot;
end

----------------
-- Entry
----------------

local formations = {
  Formation:New(
    "Fingertip",
    "45°, 75ft separation",
    {
      [1] = Position:New({40, 50}, {70, 80}),
      [2] = Position:New({40, 50}, {140, 160}),
      [3] = Position:New({40, 50}, {70, 80}),
      [4] = Position:New({40, 50}, {140, 160})
    }),

  Formation:New(
    "Route",
    "45°, 500ft separation",
    {
      [1] = Position:New({40, 50}, {480, 520}),
      [2] = Position:New({40, 50}, {980, 1020}),
      [3] = Position:New({40, 50}, {480, 520}),
      [4] = Position:New({40, 50}, {980, 1020})
    }),

  Formation:New(
    "Fighting Wing",
    "60-70°, 500-3000ft separation",
    {
      [1] = Position:New({55, 75}, {480, 3020}),
      [2] = Position:New({55, 75}, {1020, 6020}),
      [3] = Position:New({55, 75}, {480, 3020}),
      [4] = Position:New({55, 75}, {1020, 6020})
    })
}

function FormationInstructor(instructorGroupName, studentGroupName)
  local instructor_group = GROUP:FindByName(instructorGroupName);
  local instructor_unit = instructor_group:GetUnits()[1];

  local student_group = GROUP:FindByName(studentGroupName);
  local student_clients = student_group:GetUnits();

  local students = {};

  local updateTimer = nil;

  local selectedFormation = formations[1];

  local function updateStudents()
    local anyAlive = false;
    local report = REPORT:New();

    report:Add(selectedFormation:GetDescription());

    for i = 1, #students do
      local student = students[i];

      if (student:IsAlive()) then
        anyAlive = true;
        student:Update(instructor_unit);
        report:Add("-----");
        report:Add(student:GetReportLine());
      else
        student:GetScore():Reset();
      end
    end

    if (not anyAlive) then
      if (updateTimer) then
        updateTimer:Stop();
        updateTimer = nil;
      end

      return;
    end

    MESSAGE:New(report:Text(), 1, nil, true):ToBlue();
  end

  local function onStudentJoined(student)
    -- MESSAGE:New("Joined", 1):ToBlue();

    student:SetFormation(formations[1]);

    if (not instructor_group:IsActive()) then
      instructor_group:Activate();
    end

    if (not updateTimer) then
      -- MESSAGE:New("Start timer", 1):ToBlue();
      updateTimer = TIMER:New(updateStudents):Start(1, updateInterval, nil);
    end
  end

  for i = 1, #student_clients do
    local student_client = student_group:GetUnit(i):GetClient();
    local student = Student:New(student_client, i);

    student_client:Alive(function () onStudentJoined(student) end);
    students[#students + 1] = student;
  end

  local menu = MENU_GROUP:New(student_group, "Select Formation");

  for i = 1, #formations do
    local formation = formations[i];
    MENU_GROUP_COMMAND:New(student_group, formations[i].name, menu, function ()
      for j = 1, #students do
        students[j]:SetFormation(formation);
      end
      selectedFormation = formation;
    end);
  end

end
