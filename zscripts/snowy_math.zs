// Constants //

const PI = 3.14159;

// Animation Curves //

class AnimationPoint final
{
	enum AnimationSmoothingType
	{
		AST_Linear = 0,
		AST_EaseIn = 1,
		AST_EaseOut = 2,
		AST_EaseInOut = 3
	}

	int smoothing_type;
	double value;
	double length; // in tics

	static AnimationPoint Create(double value, double length = 0.0, int smoothing_type = 0)
	{
		AnimationPoint point = New('AnimationPoint');
		point.value = value;
		point.length = length;
		point.smoothing_type = smoothing_type;
		return point;
	}
}

class AnimationCurve final
{
	// Variables //

	protected array<AnimationPoint> points;
	protected bool loop;

	protected int current_point_idx;

	protected double relative_tic;
	protected double current_tic; // in tics
	protected double animation_length; // in tics

	// Methods //
	static AnimationCurve Create(bool loop = true)
	{
		AnimationCurve animation_curve = New('AnimationCurve');;
		animation_curve.loop = true;
		return animation_curve;
	}

	/* Getters */
	clearscope AnimationPoint GetPoint(int point_idx) const 
	{
		if (loop) return points[point_idx % points.Size()];
		return points[clamp(point_idx, 0, points.Size() - 1)];
	}

	clearscope AnimationPoint StartPoint() const { return points[0]; }
	clearscope AnimationPoint EndPoint() const { return points[points.Size() - 1]; }

	clearscope bool IsFinished() const { return current_tic >= animation_length; }
	clearscope double GetAnimationLengthInTics() const { return animation_length; }
	clearscope double GetCurrentTimeInTics() const { return current_tic; }
	
	/* Setters */
	void SetPointValue(int point_idx, double value)
	{
		AnimationPoint point = GetPoint(point_idx);
		if (point) point.value = value;
	}

	void SetPointLength(int point_idx, double length)
	{
		AnimationPoint point = GetPoint(point_idx);
		if (point) point.length = length;
	}

	void SetPointSmoothingType(int point_idx, int smoothing_type)
	{
		AnimationPoint point = GetPoint(point_idx);
		if (point) point.smoothing_type = smoothing_type;
	}

	/* Utilities */
	AnimationCurve AddPoint(double value, double length = 0.0, int smoothing_type = 0)
	{
		AnimationPoint last_point; 
		if (points.Size() > 0) last_point = EndPoint();

		if (last_point && last_point.length ~== 0.0 && last_point.value == value) 
		{
			// Modify the last point
			last_point.length = length;
			last_point.smoothing_type = smoothing_type;
		}
		else
		{
			AnimationPoint point = AnimationPoint.Create(value, length, smoothing_type);
			points.Push(point);
		}
		
		animation_length += length;
		AnimationUpdate();

		return self;
	}

	AnimationCurve AddStartAndEndPoint(double starting_value, double ending_value, double length = 0.0, int smoothing_type = 0)
	{
		AddPoint(starting_value, length, smoothing_type);
		AddPoint(ending_value);

		return self;
	}

	/* Usage */

	void TickAnimation() // Call to progress the animation by 1/35 of a second
	{
		current_tic++;
		AnimationUpdate();
	}

	clearscope double GetValue() const // Returns the current value of the animation at the current time
	{	
		AnimationPoint point_a = GetPoint(current_point_idx);
		AnimationPoint point_b = GetPoint(current_point_idx + 1);

		double t = double(relative_tic) / double(point_a.length);

		switch(point_a.smoothing_type)
		{
		case AnimationPoint.AST_EaseIn:
		{
			t = SnowyMath.EaseIn(t);
			break;
		}
		case AnimationPoint.AST_EaseOut:
		{
			t = SnowyMath.EaseOut(t);
			break;
		}
		case AnimationPoint.AST_EaseInOut:
		{
			t = SnowyMath.EaseInOut(t);
			break;
		}
		}

		return SnowyMath.Lerp(point_a.value, point_b.value, t);
	}

	/* Misc */

	private void AnimationUpdate()
	{
		AnimationPoint point;
		double current_length = 0.0;
		for(int i = 0; i < points.Size(); i++)
		{
			point = points[i];

			if (current_tic < point.length + current_length)
			{
				current_point_idx = i;
				relative_tic = current_tic - current_length;
				break;
			}

			current_length += point.length;
		}
	}
}

	


// Math Functions //

class SnowyMath
{
	// Smoothing Functions //

	clearscope static double Flip(double t)
	{
		return 1.0 - t;
	}

	clearscope static double EaseIn(double t)
	{
		return t * t;
	}

	clearscope static double EaseOut(double t)
	{
		return Flip(Flip(t) * Flip(t));
	}

	clearscope static double EaseInOut(double t)
	{
		return Lerp(EaseIn(t), EaseOut(t), t);
	}

	clearscope static double Lerp(double a, double b, double t) 
	{
		return (a * Flip(t)) + (b * t);
	}

	clearscope static double LinearMap (double t, double min, double max, double a, double b, bool clamp = true) 
	{
		double value = (t - min) * (b - a) / (max - min) + a;
		if (clamp) return clamp(value, min(a, b), max(a, b));
		return value;
	}

	clearscope static double SmoothOvershoot(double a, double b, double t, double duration = 0.1, double frequency = 2.0, double decay = 5.0)
	{
		if (t < duration) 
			return LinearMap(t, 0, duration, a, b);
		else
		{
			double amp = (b - a) / duration;
			double w = frequency * PI * 2;
			return b + amp * (Sin((t - duration) * w) / Exp(decay * (t - duration)) / w);
		}
	}


	// Vector Math //

	/* Return a vector where the lengths are normalized within a radial space */
	clearscope static vector2 NormalizeVec2(vector2 a)
	{
		double magnitude = a.Length();
		vector2 b = a;

		if (magnitude > 0)
		{
			if (abs(a.x) > 0) b.x = (a.x / abs(a.x)) * (a.x * a.x) / magnitude;
			if (abs(a.y) > 0) b.y = (a.y / abs(a.y)) * (a.y * a.y) / magnitude;
		}

		return b;
	}

	/* Return 2 doubles where the lengths are normalized within a radial space */
	clearscope static double, double NormalizeSpeeds(double forward, double side)
	{
		vector2 vec = NormalizeVec2((forward, side));
		return vec.x, vec.y;
	}

}